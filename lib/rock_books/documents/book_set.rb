require 'awesome_print'

require_relative 'chart_of_accounts'
require_relative 'journal'
require_relative '../filters/journal_entry_filters'  # for shell mode
require_relative '../reports/balance_sheet'
require_relative '../reports/multidoc_transaction_report'
require_relative '../reports/transaction_report'

module RockBooks

  class BookSet < Struct.new(:chart_of_accounts, :journals)

    FILTERS = JournalEntryFilters

    # Uses all *.rbt files in the specified directory; uses @doc_type to determine which
    # is the chart of accounts and which are journals.
    # To exclude a file, make the extension other than .rdt.
    def self.from_directory(directory)

      find_doc_type = ->(filespec) do
        lines = File.readlines(filespec)
        doc_type_line = lines.detect { |line| /^@doc_type: /.match(line) }
        if doc_type_line.nil?
          nil
        else
          doc_type_line.split(/^@doc_type: /).last.strip
        end
      end

      files = Dir[File.join(directory, '*.rbt')]
      files_with_types = files.each_with_object({}) do |filespec, files_with_types|
        files_with_types[filespec] = find_doc_type.(filespec)
      end


      validate_chart_of_account_count = ->(chart_of_account_files) do
        size = chart_of_account_files.size

        if size == 0
          raise Error.new("Chart of accounts file not found in directory #{directory}.\n" +
              " Does it have a '@doc_type: chart_of_accounts' line?" +
              " Files found were:\n" +
              files_with_types.ai)
        elsif size > 1
          raise Error.new("Expected only 1 chart of accounts file but found: #{chart_of_account_files}.")
        end
      end

      validate_journal_file_count = ->(journal_files) do
        if journal_files.size == 0
          raise Error.new("No journal files found in directory #{directory}. " +
                          "A journal file must contain the line '@doc_type: journal'")
        end
      end

      select_files_of_type = ->(target_doc_type_regex) do
        files_with_types.select { |filespec, doc_type| target_doc_type_regex === doc_type }.keys
      end

      chart_of_account_files = select_files_of_type.('chart_of_accounts')
      validate_chart_of_account_count.(chart_of_account_files)

      journal_files = select_files_of_type.(/journal/) # include 'journal' and 'general_journal'
      validate_journal_file_count.(journal_files)

      chart_of_accounts = ChartOfAccounts.from_file(chart_of_account_files.first)
      journals = journal_files.map { |fs| Journal.from_file(chart_of_accounts, fs) }
      self.new(chart_of_accounts, journals)
    end


    def multidoc_transaction_report(filter)
      MultidocTransactionReport.new(chart_of_accounts, journals).call(filter)
    end


    def singledoc_transaction_report(journal, filter)
      TransactionReport.new(chart_of_accounts, journal).call(filter)
    end


    def balance_sheet_report(journals)
      BalanceSheet.new(chart_of_accounts, journals, end_date = Time.now.to_date).call
    end


    def all_reports(filter = nil)
      report_hash = journals.each_with_object({}) do |journal, report_hash|
        report_hash[journal.short_name] = singledoc_transaction_report(journal, filter)
      end
      report_hash['all'] = multidoc_transaction_report(filter)
      report_hash['balance_sheet'] = balance_sheet_report(journals)
      report_hash
    end


    def all_reports_to_files(directory = '.', filter = nil)
      reports = all_reports(filter)
      reports.each do |short_name, report_text|
        filespec = File.join(directory, "#{short_name}.rpt")
        File.write(filespec, report_text)
        puts "Created report for #{short_name} at #{filespec}."
      end
    end


    def journal_names
      journals.map(&:short_name)
    end
    alias_method :jnames, :journal_names
  end

end
