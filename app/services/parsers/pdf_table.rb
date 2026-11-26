module Parsers
  # Groups positioned PDF text runs into table rows.
  #
  # Each row is anchored on a run in the date column. Every other run is assigned
  # to the anchor with the closest vertical position (within `tolerance`), which
  # keeps descriptions that wrap above/below the date line attached to the right row.
  module PdfTable
    Row = Struct.new(:page, :y, :anchor, :runs, keyword_init: true) do
      # Text of runs whose x start falls in [min_x, max_x), top-to-bottom, left-to-right.
      def text_in(min_x, max_x)
        runs.select { |r| r.x >= min_x && r.x < max_x }
            .sort_by { |r| [-r.y.round(1), r.x] }
            .map { |r| r.text.strip }
            .join(' ')
            .squeeze(' ')
            .strip
      end

      # Runs on the anchor's own baseline (not wrapped lines).
      def same_line_runs(epsilon = 2.0)
        runs.select { |r| (r.y - y).abs <= epsilon }
      end
    end

    module_function

    def rows(reader, anchor:, anchor_max_x:, tolerance:, skip: nil)
      reader.pages.each_with_index.flat_map do |page, index|
        runs = page.runs(merge: true)
        anchors = runs.select { |r| r.x < anchor_max_x && r.text.strip.match?(anchor) }
        next [] if anchors.empty?

        rows = anchors.map { |a| Row.new(page: index + 1, y: a.y, anchor: a.text.strip, runs: []) }

        (runs - anchors).each do |run|
          next if skip && run.text.strip.match?(skip)

          nearest = rows.min_by { |row| (row.y - run.y).abs }
          nearest.runs << run if (nearest.y - run.y).abs <= tolerance
        end

        rows.sort_by { |row| -row.y }
      end
    end

    def brl_to_f(value)
      value.delete('.').tr(',', '.').to_f
    end
  end
end
