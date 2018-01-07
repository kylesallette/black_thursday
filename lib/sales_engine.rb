require_relative '../lib/item_repository'
require_relative '../lib/merchant_repository'
require_relative '../lib/invoice_repository'
require 'pry'


class SalesEngine

  attr_reader :items,
              :merchants,
              :invoices

  def initialize(csv_files)
    csv_files  = merge_in_given_csvs(csv_files)
    @invoices  = InvoiceRepository.new(csv_files[:invoices], self)
    @items     = ItemRepository.new(csv_files[:items], self)
    @merchants = MerchantRepository.new(csv_files[:merchants], self)
  end

  def merge_in_given_csvs(given_csvs)
    default_csvs.merge(given_csvs)
  end

  def default_csvs
    { items: './data/items_blank.csv',
      merchants: './data/merchants_blank.csv',
      invoices: './data/invoices_blank.csv' }
  end

  def self.from_csv(csv_files)
    new(csv_files)
  end

  def find_item_by_merchant_id(id)
    items.find_item(id)
  end

  def find_merchant_by_id(id)
    merchants.find_by_id(id)
  end

  def grab_array_of_merchant_items
    merchants.grab_array_of_items
  end

  def grab_array_of_merchant_invoices
    merchants.grab_array_of_invoices
  end

  def grab_all_merchants
    merchants.all
  end

  def grab_all_items
    items.all
  end

  def grab_all_invoices
    invoices.all
  end

  def invoice_by_merchant_id(id)
    invoices.find_all_by_merchant_id(id)
  end

  def merchant_by_invoice_id(id)
    merchants.find_by_id(id)
  end

end
