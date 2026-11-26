# Builds stand-ins for PDF::Reader so layout parsers can be tested without real
# (personal) bank statements. Runs are [x, y, text] triples.
module FakePdf
  Page = Struct.new(:text, :run_list) do
    def runs(merge: true)
      run_list
    end
  end

  Reader = Struct.new(:pages)

  def fake_pdf_reader(*pages)
    Reader.new(pages.map do |page|
      runs = page.fetch(:runs).map { |x, y, text| PDF::Reader::TextRun.new(x, y, 50, 10, text) }
      Page.new(page.fetch(:text), runs)
    end)
  end
end

RSpec.configure { |config| config.include FakePdf }
