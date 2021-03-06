require 'bigdecimal'
require 'pry'
require_relative 'sales_engine'
require_relative 'calculations'
require 'pry'

class SalesAnalyst

  include Calculations

  attr_reader :se,
              :average_item_prices

  def initialize(se)
    @se = se
  end

  def average_items_per_merchant
    (se.grab_all_items.count / se.grab_all_merchants.count.to_f).round(2)
  end

  def average_invoices_per_merchant
    (se.grab_all_invoices.count / se.grab_all_merchants.count.to_f).round(2)
  end

  def number_of_items_per_merchant
    se.items_per_merchant
  end

  def number_of_invoices_per_merchant
    se.invoices_per_merchant
  end

  def item_price_standard_deviation
    price_variance = se.items.all.reduce(0) do |result, item|
      result += (item.unit_price.to_i - item_prices_mean) ** 2
    end
    (Math.sqrt(price_variance/(se.items.all.count - 1))).round(2)
  end

  def average_items_per_merchant_standard_deviation
    var = variance(average_items_per_merchant, number_of_items_per_merchant)
    standard_dev(var, se.grab_all_merchants.count - 1)
  end

  def average_invoices_per_merchant_standard_deviation
    b = variance(average_invoices_per_merchant, number_of_invoices_per_merchant)
    standard_dev(b, se.grab_all_merchants.count - 1)
  end

  def item_prices_mean
    items       = se.grab_all_items
    prices = items.reduce(0) { |result, item| result += item.unit_price.to_i}
    (prices / items.count).round(2)
  end

  def invoice_mean
    array = number_of_invoices_per_merchant
    (array.inject(0) { |sum, x| sum += x } / array.size.to_f).round(2)
  end

  def merchants_with_high_item_count
    count = average_items_per_merchant +
            average_items_per_merchant_standard_deviation
    se.grab_all_merchants.find_all do |merchant|
      merchant if merchant.items.count > count
    end
  end

  def average_item_price_for_merchant(merchant_id)
    merchant           = se.find_merchant_by_id(merchant_id)
    items              = se.find_item_by_merchant_id(merchant_id)
    summed_item_prices = items.reduce(0) { |res, item| res += item.unit_price}
    (summed_item_prices / items.count).round(2)
  end

  def average_average_price_per_merchant
    merchants = se.grab_all_merchants
    price = merchants.reduce(0) do |result, merch|
      result +=  average_item_price_for_merchant(merch.id)
    end
    (price / merchants.count).round(2)
  end

  def top_merchants_by_invoice_count
    double_deviation = (average_invoices_per_merchant_standard_deviation * 2)
    mean = average_invoices_per_merchant + double_deviation
    se.grab_all_merchants.find_all do |merchant|
      merchant.invoices.count > mean
    end
  end

  def bottom_merchants_by_invoice_count
    double_deviation = (average_invoices_per_merchant_standard_deviation * 2)
    mean = average_invoices_per_merchant - double_deviation
    se.grab_all_merchants.find_all do |merchant|
      merchant.invoices.count < mean
    end
  end

  def golden_items
    double_deviation = (item_price_standard_deviation * 2)
    se.grab_all_items.find_all do |item|
      price = item.unit_price
      item if price > double_deviation
    end
  end

  def group_invoices_by_day
    se.grab_all_invoices.group_by do |invoice|
      invoice.created_at.strftime("%A")
    end
  end

  def average_invoices_per_day
    (se.grab_all_invoices.count / 7)
  end

  def invoices_per_day
    group_invoices_by_day.values.map(&:count)
  end

  def average_invoices_per_day_standard_deviation
    var = variance(average_invoices_per_day, invoices_per_day)
    standard_dev(var, 6)
  end

  def top_days_by_invoice_count
    m = average_invoices_per_day + average_invoices_per_day_standard_deviation
    group_invoices_by_day.map do |day, invoices|
      day if invoices.count > m
    end.delete_if { |day| day.nil? }
  end

  def group_by_status
    se.grab_all_invoices.group_by(&:status)
  end

  def invoice_status(status)
    ((group_by_status[status].count / se.grab_all_invoices.count.to_f) * 100).round(2)
  end

  def total_revenue_by_date(date)
    grab_invoice_items_by_invoice_date(date).sum do |invoice_item|
      (invoice_item.unit_price * invoice_item.quantity)
    end
  end

  def grab_invoice_by_date(date)
    se.grab_all_invoices.select do |invoice|
      invoice.created_at.to_i == date.to_i
    end
  end

  def grab_invoice_items_by_invoice_date(date)
    invoice = grab_invoice_by_date(date)
    se.invoice_items.all.find_all do |invoice_item|
      invoice_item.invoice_id == invoice.first.id
    end
  end

  def top_revenue_earners(totals = 20)
    merchants_ranked_by_revenue[0...totals]
  end

  def merchants_ranked_by_revenue
    se.grab_all_merchants.sort_by(&:revenue).reverse
  end

  def merchants_with_only_one_item
    se.grab_all_merchants.find_all do |merchant|
      merchant.items.count == 1
    end
  end

  def merchants_with_pending_invoices
    se.grab_all_merchants.find_all do |merchant|
      merchant.invoices.any? do |invoice|
        invoice.transactions.none? { |sale| sale.result == "success" }
      end
    end
  end

  def revenue_by_merchant(merchant_id)
    se.find_merchant_by_id(merchant_id).revenue if !se.find_merchant_by_id(merchant_id).nil?
  end

  def merchants_with_only_one_item_registered_in_month(month_name)
    merchants_with_only_one_item.find_all do |merchant|
      merchant.created_at.strftime("%B") == month_name
    end
  end

  def grab_paid_invoice_items_from_merchants(merchant_id)
    merchant = se.merchants.find_by_id(merchant_id)
    invoice_items = merchant.invoices.map do |invoice|
      invoice.invoice_items if invoice.is_paid_in_full?
    end.compact.flatten(1)
  end

  def group_items_to_invoice_attributes(merchant_id)
    invoice_items = grab_paid_invoice_items_from_merchants(merchant_id)
    invoice_items.reduce(Hash.new(0)) do |result, inv_item|
      result.merge!({inv_item.item_id => [inv_item.quantity, inv_item.unit_price]})
    end
  end

  def sort_by_quantity(merchant_id)
    item_attributes = group_items_to_invoice_attributes(merchant_id)
    item_attributes.sort_by { |item, attributes| attributes[0] }.reverse
  end

  def grab_most_sold_items(merchant_id)
    highest_quantity = sort_by_quantity(merchant_id)[0][1][0]
    sort_by_quantity(merchant_id).map do |item|
      item[0] if item[1][0] == highest_quantity
    end.compact
  end

  def most_sold_item_for_merchant(merchant_id)
    grab_most_sold_items(merchant_id).map do |item_id|
      se.items.find_by_id(item_id)
    end.compact
  end

  def group_items_to_revenue(merchant_id)
    items_to_invoices = group_items_to_invoice_attributes(merchant_id)
    items_to_invoices.transform_values do |attributes|
      (attributes[0] * attributes[1])
    end
  end

  def top_item_by_revenue_id(merchant_id)
    group_items_to_revenue(merchant_id).sort_by do |items, revenue|
      revenue
    end.reverse.flatten(2)
  end

  def best_item_for_merchant(merchant_id)
    se.items.find_by_id(top_item_by_revenue_id(merchant_id).first)
  end

end
