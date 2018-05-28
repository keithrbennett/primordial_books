require_relative '../filters/journal_entry_filters'

module RockBooks

# Reports the balance sheet as of the specified date.
# Unlike other reports, we need to process transactions from the beginning of time
# in order to calculate the correct balances, so we ignore the global $filter.
class BalanceSheet < Struct.new(:chart_of_accounts, :journals, :end_date, :page_width)

  include Reporter

  def initialize(chart_of_accounts, journals, end_date = Time.now.to_date, page_width = 80)
    super
  end


  def format_header
    <<~HEREDOC
    #{banner_line}
    #{center("Balance Sheet -- #{end_date}")}
    #{banner_line}

    HEREDOC
  end


  def process_section(totals, section_type)
    account_codes_this_section = chart_of_accounts.account_codes_of_type(section_type)
    totals_this_section = totals.select do |account_code, amount|
      account_codes_this_section.include?(account_code)
    end

    output = "\n\nAccount Type: #{section_type}\n"
    output << generate_and_format_totals(totals_this_section, chart_of_accounts)
    output
  end


  def generate_report
    self.page_width ||= 80
    filter = RockBooks::JournalEntryFilters.date_on_or_before(end_date)
    acct_amounts = acct_amounts_in_documents(journals, filter)
    totals = AcctAmount.aggregate_amounts_by_account(acct_amounts)
    output = format_header
    %i(asset  liability  owners_equity).each do |section_type|
      output << process_section(totals, section_type) << "\n\n"
    end
    output
  end

  alias_method :to_s, :generate_report
  alias_method :call, :generate_report

end
end
