require_relative 'data/bs_is_data'
require_relative '../filters/journal_entry_filters'
require_relative '../documents/journal'
require_relative 'report_context'

module RockBooks

# Reports the balance sheet as of the specified date.
# Unlike other reports, we need to process transactions from the beginning of time
# in order to calculate the correct balances, so we ignore the global $filter.
class BalanceSheet

  include Reporter

  attr_accessor :context, :data

  def initialize(report_context, data)
    @context = report_context
    @data = data
  end


  def generate
    erb_render_hashes('balance_sheet.txt.erb', data, template_presentation_context)
  end
end
end
