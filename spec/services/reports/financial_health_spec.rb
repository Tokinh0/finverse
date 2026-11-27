require "rails_helper"

RSpec.describe Reports::FinancialHealth do
  let(:conforto) { create(:category, name: "Conforto") }
  let(:contas) { create(:category, name: "Contas") }
  let(:food) { create(:subcategory, name: "Food", category: conforto, subcategory_type: "expense") }
  let(:bills) { create(:subcategory, name: "Luz", category: contas, subcategory_type: "expense") }
  let(:salary) { create(:subcategory, name: "Salario", subcategory_type: "gain") }
  let(:savings) { create(:subcategory, name: "Poupanca", subcategory_type: "investment") }
  let(:transfer) { create(:subcategory, name: "Transfer", subcategory_type: "transfer") }

  def tx(subcategory, amount, date, type = "debit", name: "TX")
    create(:transaction, subcategory: subcategory, amount: amount, transaction_date: date, transaction_type: type, name: name)
  end

  before do
    # previous quarter (Apr-Jun 2025)
    tx(salary, 1000, Date.new(2025, 5, 5), "credit")
    tx(food, 100, Date.new(2025, 5, 10))
    # current quarter (Jul-Sep 2025)
    tx(salary, 2000, Date.new(2025, 9, 5), "credit")
    tx(food, 300, Date.new(2025, 9, 10), name: "IFOOD 123")
    tx(food, 50, Date.new(2025, 9, 11), "credit", name: "ESTORNO") # refund lowers spending
    tx(bills, 250, Date.new(2025, 8, 1), name: "POWER_COMPANY")
    tx(savings, 400, Date.new(2025, 9, 2))
    tx(transfer, 999, Date.new(2025, 9, 3)) # ignored
    # last year, for the year comparison
    tx(food, 80, Date.new(2024, 9, 10))
  end

  subject(:report) { described_class.call(period: "3") }

  it "defaults to the latest month and the requested period" do
    expect(report).to include(as_of: "2025-09", period_months: 3,
                              range: { from: "2025-07-01", to: "2025-09-30" },
                              previous_range: { from: "2025-04-01", to: "2025-06-30" },
                              years_available: [ 2025, 2024 ])
  end

  it "totals income, net spending, investments and savings rate, ignoring transfers" do
    expect(report[:summary][:current]).to eq(income: 2000.0, expenses: 500.0, invested: 400.0, net: 1500.0, savings_rate: 0.75)
    expect(report[:summary][:previous]).to include(income: 1000.0, expenses: 100.0, savings_rate: 0.9)
  end

  it "ranks expense categories with share, change and subcategories" do
    expect(report[:categories].map { |c| c.slice(:name, :total, :share, :previous_total, :change_pct) }).to eq([
      { name: "Conforto", total: 250.0, share: 0.5, previous_total: 100.0, change_pct: 1.5 },
      { name: "Contas", total: 250.0, share: 0.5, previous_total: 0.0, change_pct: nil }
    ])
    expect(report[:categories].first[:subcategories]).to eq([ { id: food.id, name: "Food", total: 250.0 } ])
  end

  it "builds 12 months of category trends with last month, previous month and 6-month average" do
    trends = report[:trends]
    food_trend = trends[:categories].find { |c| c[:name] == "Conforto" }

    expect(trends[:months].first).to eq("2024-10")
    expect(trends[:months].last).to eq("2025-09")
    expect(trends[:totals].last(2)).to eq([ 250.0, 250.0 ])
    expect(food_trend).to include(last_month: 250.0, previous_month: 0.0, average: 16.67, change_vs_previous_pct: nil, change_vs_average_pct: 14.0)
  end

  it "summarizes the year against the previous one" do
    year = report[:year]

    expect(year).to include(year: 2025, previous_year: 2024, months_with_data: 3)
    expect(year[:monthly][8]).to include(month: 9, has_data: true, expenses: 250.0, previous_year_expenses: 80.0)
    expect(year[:monthly][0]).to include(has_data: false, previous_year_expenses: nil)
    expect(year[:best_month]).to include(month: 9, net: 1750.0)
    expect(year[:worst_month]).to include(month: 8, net: -250.0)
    expect(year[:categories].find { |c| c[:name] == "Conforto" }).to include(total: 350.0, previous_total: 80.0)
    expect(year[:top_merchants].first).to eq(name: "IFOOD 123", total: 300.0, count: 1, subcategory: "Food")
  end

  it "accepts an explicit month, year and falls back on invalid input" do
    other = described_class.call(period: "7", as_of: "2025-05", year: "2024")

    expect(other).to include(as_of: "2025-05", period_months: 3)
    expect(other[:year][:year]).to eq(2024)
  end

  it "handles an empty database" do
    Transaction.delete_all

    expect(described_class.call).to eq(as_of: nil, period_months: 3, months_available: [], years_available: [])
  end
end
