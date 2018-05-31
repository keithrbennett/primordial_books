module RockBooks

class JournalEntry < Struct.new(:date, :acct_amounts, :description, :doc_short_name)

  def self.entries_acct_amounts(entries)
    acct_amounts = entries.each_with_object([]) do |entry, acct_amounts|
      acct_amounts << entry.acct_amounts
    end
    acct_amounts.flatten!
    acct_amounts
  end


  def self.entries_containing_account_code(entries, account_code)
    entries.select { |entry| entry.contains_account?(account_code) }
  end


  def self.total_for_code(entries, account_code)
    entries.map { |entry| entry.total_for_code(account_code)}.sum
  end


  def total_for_code(account_code)
    acct_amounts_with_code(account_code).map(&:amount).sum
  end


  def acct_amounts_with_code(account_code)
    acct_amounts.select { |acct_amount| acct_amount.code == account_code }
  end


  def total_amount
    acct_amounts.inject(0) { |sum, aa| sum + aa.amount }
  end


  def balanced?
    total_amount == 0.0
  end


  def contains_account?(account_code)
    acct_amounts.any? { |acct_amount| acct_amount.code == account_code }
  end
end

end
