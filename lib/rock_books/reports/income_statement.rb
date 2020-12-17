require_relative '../documents/journal'
require_relative 'report_context'

module RockBooks


  class IncomeStatement

  include Reporter

  attr_accessor :context


  def initialize(report_context)
    @context = report_context
  end


  def start_date
    context.chart_of_accounts.start_date
  end


  def end_date
    context.chart_of_accounts.end_date
  end


  def generate_header
    lines = [banner_line]
    lines << center(context.entity || 'Unspecified Entity')
    lines << "#{center("Income Statement -- #{start_date} to #{end_date}")}"
    lines << banner_line
    lines << ''
    lines << ''
    lines << ''
    lines.join("\n")
  end


  def generate_report
    filter = RockBooks::JournalEntryFilters.date_in_range(start_date, end_date)
    acct_amounts = Journal.acct_amounts_in_documents(context.journals, filter)
    totals = AcctAmount.aggregate_amounts_by_account(acct_amounts) # e.g. totals.first is "comp.hw"=>19937.24
    output = generate_header

    income_output,  income_total  = generate_account_type_section('Income',   totals, :income,  true)
    expense_output, expense_total = generate_account_type_section('Expenses', totals, :expense, false)

    grand_total = income_total - expense_total

    output << [income_output, expense_output].join("\n\n")
    output << "\n#{"%12.2f    Net Income" % grand_total}\n============\n"
    output
  end

alias_method :to_s, :generate_report
alias_method :call, :generate_report


end
end
