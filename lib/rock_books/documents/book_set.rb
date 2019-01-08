require 'awesome_print'

require_relative 'chart_of_accounts'
require_relative 'journal'
require_relative '../filters/journal_entry_filters'  # for shell mode
require_relative '../helpers/parse_helper'
require_relative '../reports/balance_sheet'
require_relative '../reports/income_statement'
require_relative '../reports/multidoc_transaction_report'
require_relative '../reports/receipts_report'
require_relative '../reports/report_context'
require_relative '../reports/transaction_report'
require_relative '../reports/tx_by_account'
require_relative '../reports/tx_one_account'

require 'open3'

module RockBooks

  class BookSet < Struct.new(:run_options, :chart_of_accounts, :journals)

    FILTERS = JournalEntryFilters


    def initialize(run_options, chart_of_accounts, journals)
      super
    end


    def report_context
      @report_context ||= ReportContext.new(chart_of_accounts, journals, nil, nil, 80)
    end


    def all_reports(filter = nil)
      context = report_context
      report_hash = context.journals.each_with_object({}) do |journal, report_hash|
        report_hash[journal.short_name] = TransactionReport.new(journal, context).call(filter)
      end
      report_hash['all_txns_by_date'] = MultidocTransactionReport.new(context).call(filter)
      report_hash['all_txns_by_amount'] = MultidocTransactionReport.new(context).call(filter, :amount)
      report_hash['all_txns_by_acct'] = TxByAccount.new(context).call
      report_hash['balance_sheet'] = BalanceSheet.new(context).call
      report_hash['income_statement'] = IncomeStatement.new(context).call

      if run_options.do_receipts
        report_hash['receipts'] = ReceiptsReport.new(context, *missing_and_existing_receipts).call
      end

      chart_of_accounts.accounts.each do |account|
        key = 'acct_' + account.code
        report = TxOneAccount.new(context, account.code).call
        report_hash[key] = report
      end
      report_hash
    end


    def run_command(command)
      puts "\n----\nRunning command: #{command}"
      stdout, stderr, status = Open3.capture3(command)
      puts "Status was #{status}."
      unless stdout.size == 0
        puts "\nStdout was:\n\n#{stdout}"
      end
      unless stderr.size == 0
        puts "\nStderr was:\n\n#{stderr}"
      end
      puts
      stdout
    end


    def all_reports_to_files(directory = '.', filter = nil)
      reports = all_reports(filter)

      # "./pdf/short_name.pdf" or "./pdf/single_account/short_name.pdf"
      build_filespec = ->(directory, short_name, file_format) do
        fragments = [directory, file_format, "#{short_name}.#{file_format}"]
        is_acct_report =  /^acct_/.match(short_name)
        if is_acct_report
          fragments.insert(2, SINGLE_ACCT_SUBDIR)
        end
        File.join(*fragments)
      end

      create_index_html = -> do
        filespec = build_filespec.(directory, 'index', 'html')
        File.write(filespec, index_html_content(directory))
      end

      reports.each do |short_name, report_text|
        txt_filespec  = build_filespec.(directory, short_name, 'txt')
        html_filespec = build_filespec.(directory, short_name, 'html')
        pdf_filespec  = build_filespec.(directory, short_name, 'pdf')

        FileUtils.mkdir_p(File.dirname(txt_filespec))
        FileUtils.mkdir_p(File.dirname(html_filespec))
        FileUtils.mkdir_p(File.dirname(pdf_filespec))

        File.write(txt_filespec, report_text)
        run_command("textutil -convert html -font 'Menlo Regular' -fontsize 12 #{txt_filespec} -output #{html_filespec}")
        run_command("cupsfilter #{html_filespec} > #{pdf_filespec}")
        puts "Created reports in txt, html, and pdf for #{"%-20s" % short_name} at #{File.dirname(txt_filespec)}.\n\n\n"
      end

      create_index_html.()
    end


    def journal_names
      journals.map(&:short_name)
    end
    alias_method :jnames, :journal_names


    # Note: Unfiltered!
    def all_acct_amounts
      @all_acct_amounts ||= Journal.acct_amounts_in_documents(journals)
    end


    def all_entries
      @all_entries ||= Journal.entries_in_documents(journals)
    end


    def receipt_full_filespec(receipt_filespec)
      File.join(run_options.receipt_dir, receipt_filespec)
    end


    def missing_and_existing_receipts
      missing = []; existing = []
      all_entries.each do |entry|
        entry.receipts.each do |receipt|
          file_exists = File.file?(receipt_full_filespec(receipt))
          list = (file_exists ? existing : missing)
          list << { receipt: receipt, journal: entry.doc_short_name }
        end
      end
      [missing, existing]
    end

    def index_html_content(directory)
      content = <<~HEREDOC
        <html>
          <body>

            <h1>#{chart_of_accounts.entity}</h1>
            <h4>Reports Generated at #{DateTime.now.strftime('%Y-%m-%d_%H-%M-%S')} by RockBooks version #{RockBooks::VERSION}</h4>

            <h2>Financial Statements</h2>
            <ul>
              <li><a href='balance_sheet.html'>Balance Sheet</a></li>
              <li><a href='income_statement.html'>Income Statement</a></li>
            </ul>
            
            <h2>All Transactions</h2>
            <ul>
              <li><a href="all_txns_by_acct.html">By Account</a></li>
              <li><a href="all_txns_by_amount.html">By Amount</a></li>
              <li><a href="all_txns_by_date.html">By Date</a></li>
            </ul>

            <h2>Journals</h2>
            <ul>
      HEREDOC

      journals.each do |journal|
        filespec = journal.short_name + '.html'
        caption = "#{journal.title} -- #{journal.short_name} -- #{journal.account_code}"
        content << %Q{      <li><a href="#{filespec}">#{caption}</a></li>\n}
      end


      content << \
          "    </ul>

    <h2>Individual Accounts</h2>
    <ul>
"
      chart_of_accounts.accounts.each do |account|
        filespec = File.join('single-account', "acct_#{account.code}.html")
        caption = "#{account.name} (#{account.code})"
        content << %Q{      <li><a href="#{filespec}">#{caption}</a></li>\n}
      end

      content << "    </ul>\n"

      if run_options.do_receipts
        content << "    <h2>Receipts</h2>\n" \
                << "    <ul>\n" \
                << %Q{      <li><a href="receipts.html">Missing and Existing Receipts</a></li>\n} \
                << "    </ul>\n"
      end

      content << "
  </body>
</html>
"
      content
    end
  end
end
