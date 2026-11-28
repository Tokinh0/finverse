require "rails_helper"

RSpec.describe Reports::SavingsOpportunities do
  let(:food) { create(:subcategory, name: "Delivery", subcategory_type: "expense") }
  let(:market) { create(:subcategory, name: "Mercado", subcategory_type: "expense") }
  let(:fees) { create(:subcategory, name: "Taxas", subcategory_type: "expense") }
  let(:streaming) { create(:subcategory, name: "Assinaturas", subcategory_type: "expense") }
  let(:salary) { create(:subcategory, name: "Salario", subcategory_type: "gain") }
  let(:as_of) { Date.new(2025, 9, 1) }

  def tx(subcategory, amount, date, name, type = "debit")
    create(:transaction, subcategory: subcategory, amount: amount, transaction_date: date, transaction_type: type, name: name)
  end

  def months(from, to)
    (0..).lazy.map { |i| from + i.months }.take_while { |m| m <= to }.to_a
  end

  subject(:result) { described_class.call(as_of: as_of, period: 3) }

  def opportunity(kind, name = nil)
    result[:opportunities].find { |o| o[:kind] == kind && (name.nil? || o[:name] == name) }
  end

  context "with a year of history" do
    before do
      # Every month from Sep 2024 has data (a salary), so the baseline is Jun 2024..May 2025 minus
      # months without data: Sep 2024..Jun 2025 = 10 months.
      months(Date.new(2024, 9, 1), as_of).each { |m| tx(salary, 5000, m + 4.days, "SALARIO", "credit") }

      # Delivery used to be 2 orders of R$ 40 a month; now 6 orders of R$ 55.
      months(Date.new(2024, 9, 1), Date.new(2025, 6, 1)).each do |m|
        2.times { |i| tx(food, 40, m + (10 + i).days, "IFOOD *REST #{i}") }
      end
      months(Date.new(2025, 7, 1), as_of).each do |m|
        6.times { |i| tx(food, 55, m + (10 + i).days, "IFOOD *REST #{i}") }
      end

      # Coffee: steady, but 8 small charges a month (R$ 15 each) every month.
      months(Date.new(2024, 9, 1), as_of).each do |m|
        8.times { |i| tx(market, 15, m + (1 + i).days, "CAFE DA ESQUINA") }
      end

      # Streaming, R$ 39.90 then R$ 44.90 from August.
      months(Date.new(2025, 4, 1), Date.new(2025, 7, 1)).each { |m| tx(streaming, 39.9, m + 20.days, "STREAMFLIX") }
      months(Date.new(2025, 8, 1), as_of).each { |m| tx(streaming, 44.9, m + 20.days, "STREAMFLIX") }

      # Fees in the period.
      tx(fees, 30, Date.new(2025, 8, 5), "TARIFA PACOTE")
      tx(fees, 12.5, Date.new(2025, 9, 5), "IOF COMPRA EXTERIOR")
    end

    it "flags a merchant now well above its usual level, with orders and ticket then and now" do
      ifood = opportunity("growing_merchant")
      expect(ifood).to include(
        name: a_string_starting_with("IFOOD"),
        monthly_now: 330.0,
        monthly_before: 80.0,
        count_now: 6.0,
        count_before: 2.0,
        ticket_now: 55.0,
        ticket_before: 40.0,
        potential_monthly: 250.0,
        first_seen: "2024-09",
        subcategory: a_hash_including(name: "Delivery")
      )
      expect(ifood[:series].size).to eq(12)
      expect(ifood[:series].last).to eq(month: "2025-09", total: 330.0)
      expect(ifood[:series].first).to eq(month: "2024-10", total: 80.0)
    end

    it "flags many small charges that add up, saving one in three" do
      coffee = opportunity("frequent_small", "CAFE DA ESQUINA")
      expect(coffee).to include(monthly_now: 120.0, count_now: 8.0, ticket_now: 15.0, potential_monthly: 40.0)
    end

    it "lists subscriptions with price increases, outside the total" do
      expect(result[:subscriptions][:items]).to contain_exactly(
        a_hash_including(name: "STREAMFLIX", monthly: 44.9, months: 6, price_change: { from: 39.9, to: 44.9 })
      )
      expect(result[:subscriptions][:yearly]).to eq(538.8)
      expect(result[:opportunities].map { |o| o[:name] }).not_to include("STREAMFLIX")
    end

    it "groups bank fees and interest, all avoidable" do
      expect(opportunity("fees")).to include(monthly_now: 14.17, potential_monthly: 14.17, items: contain_exactly(
        a_hash_including(name: "TARIFA PACOTE", total: 30.0), a_hash_including(name: "IOF COMPRA EXTERIOR", total: 12.5)
      ))
    end

    it "doesn't count growth twice: a subcategory explained by its merchants isn't repeated" do
      expect(opportunity("growing_subcategory")).to be_nil
    end

    it "sums what could be saved and compares spending with before" do
      expect(result[:baseline_months]).to eq(10)
      expect(result[:summary]).to include(potential_monthly: 304.17, potential_yearly: 3650.04, lowest_month: a_hash_including(total: 200.0))
      expect(result[:opportunities].map { |o| o[:potential_monthly] }).to eq(result[:opportunities].map { |o| o[:potential_monthly] }.sort.reverse)
    end
  end

  it "flags a subcategory above its usual level when no single merchant explains it" do
    # One store at about R$ 300 a month before; now the same store plus five new ones, each too
    # small to flag on its own (amounts vary, so none looks like a subscription).
    months(Date.new(2025, 1, 1), as_of).each { |m| tx(market, m.month.odd? ? 310 : 290, m + 3.days, "SUPERMERCADO A") }
    months(Date.new(2025, 7, 1), as_of).each do |m|
      %w[B C D E F].each_with_index { |store, i| tx(market, m.month.odd? ? 45 : 35, m + (5 + i).days, "MERCADINHO #{store}") }
    end

    expect(opportunity("growing_subcategory")).to include(
      name: "Mercado", monthly_now: 511.67, monthly_before: 300.0, potential_monthly: 211.67,
      top_merchants: include(a_hash_including(name: "SUPERMERCADO A"))
    )
    expect(result[:opportunities].map { |o| o[:kind] }).to eq([ "growing_subcategory" ])
  end

  describe "subscriptions" do
    let(:recent) { months(Date.new(2025, 4, 1), as_of) }

    it "aren't monthly purchases whose amount varies, installments, big jumps or stopped charges" do
      recent.each_with_index do |m, i|
        tx(market, 900 + i * 40, m + 6.days, "SUPERMERCADO")                     # varies every month
        tx(market, 310, m + 8.days, "LOJA ELETRO PARC #{i + 1}/6")             # installments
        tx(market, i < 3 ? 180 : 520, m + 9.days, "MARKETPLACE")              # jumped, not a price change
      end
      months(Date.new(2025, 3, 1), Date.new(2025, 6, 1)).each { |m| tx(streaming, 29.9, m + 2.days, "CANCELADO TV") }

      expect(result[:subscriptions][:items]).to be_empty
    end

    it "stay out of the subcategory comparison" do
      months(Date.new(2024, 9, 1), as_of).each { |m| tx(salary, 5000, m, "SALARIO", "credit") }
      months(Date.new(2025, 5, 1), as_of).each { |m| tx(streaming, 120, m + 2.days, "ACADEMIA") }

      expect(result[:subscriptions][:items].map { |s| s[:name] }).to eq([ "ACADEMIA" ])
      expect(opportunity("growing_subcategory")).to be_nil
    end
  end

  it "shows merchant names without their order numbers" do
    months(Date.new(2025, 7, 1), as_of).each do |m|
      5.times { |i| tx(food, 20, m + i.days, "PADARIA CENTRAL #{1000 + i}") }
    end

    expect(opportunity("frequent_small")[:name]).to eq("PADARIA CENTRAL")
  end

  it "needs a few months of history before talking about growth" do
    months(Date.new(2025, 7, 1), as_of).each { |m| tx(food, 400, m + 3.days, "IFOOD") }

    expect(result[:baseline_months]).to eq(0)
    expect(result[:opportunities]).to be_empty
    expect(result[:summary]).to include(potential_monthly: 0.0, spending_before: nil, lowest_month: nil)
  end

  it "ignores credits, transfers and income" do
    transfer = create(:subcategory, subcategory_type: "transfer")
    months(Date.new(2025, 7, 1), as_of).each do |m|
      tx(transfer, 900, m, "PIX PROPRIO")
      tx(food, 500, m, "ESTORNO IFOOD", "credit")
    end

    expect(result[:opportunities]).to be_empty
    expect(result[:subscriptions][:items]).to be_empty
  end

  it "returns an empty report without data" do
    expect(described_class.call(as_of: nil, period: 3)).to include(opportunities: [], baseline_months: 0)
  end
end
