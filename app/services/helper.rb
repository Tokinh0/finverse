module Helper
  def color_for(entry)
    return "\e[32m" if entry[:type] == 'credit'
    return "\e[35m" if entry[:type] == 'unknown'

    amount = entry[:amount].abs

    case amount
    when 0..50
      "\e[38;5;240m"    # Dark Grey
    when 51..99
      "\e[38;5;245m"    # Light Grey
    when 100...300
      "\e[93m"          # Light Yellow
    when 300...500
      "\e[33m"          # Dark Yellow
    when 500...1000
      "\e[91m"          # Orange-ish Red
    when 1000...1000000
      "\e[31m"          # Red
    else
      "\e[38;5;240m"    # Dark Grey
    end
  end
end
