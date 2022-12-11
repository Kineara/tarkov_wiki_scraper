require 'kimurai'
require 'nokogiri'
require 'webdrivers'

# @driver = Selenium::WebDriver.for :chrome

class TarkovSpider < Kimurai::Base
  @name = 'tarkov_spider'
  @engine = :mechanize
  @start_urls = ['https://escapefromtarkov.fandom.com/wiki/Weapon_mods']
  @config = {
    retry_request_errors: [{ error: RuntimeError, skip_on_failure: false }]
  }

  def parse(response, url:, data: {})
    links = getLinks(response)
    # links = ['/wiki/HK417_7.62x51_16.5_inch_barrel']
    scrapeLinks(links)
  end

  def getLinks(response)
    scraped_links = []
    links = response.css('tbody tr td a')
    links.each do |mod|
      scraped_links.push(mod['href'])
    end
    scraped_links
  end

  def scrapeLinks(links)
    links.each do |link|
      item_hash = {}

      browser.visit("https://escapefromtarkov.fandom.com#{link}")
      doc = browser.current_response

      # Add name from page title
      item_hash.store('name', doc.css('h1#firstHeading').text.strip.downcase)

      # Add object attributes from info table dynamically
      table_rows = doc.css('table#va-infobox0 tbody tr#va-infobox0-content td table.va-infobox-group tbody tr')
      table_rows.each do |row|
        attribute_name = row.css('td.va-infobox-label').text.strip.downcase

        # Swap characters in attribute name
        attribute_name.gsub!('%', 'percent')
        attribute_name.gsub!(' ', '_')
        attribute_name.gsub!(' ', '_')

        attribute_value = row.css('td.va-infobox-content').text.strip.downcase
        item_hash.store(attribute_name, attribute_value) if attribute_name.length > 0 && attribute_value.length > 0
      end

      # Add mod parts
      mods = {}
      categories_index = {}

      # Add mod category names
      doc.css('div.wds-tabs__wrapper.with-bottom-border ul li div a').each_with_index do |mod, index|
        mod_category = mod.text.gsub(' ', '_').downcase
        mods.store(mod_category, {})
        categories_index.store(index, mod_category)
      end

      # Add mod category items
      doc.css('div.tabber.wds-tabber div.wds-tab__content').each_with_index do |div, index|
        items = []
        div.css('a').each do |item|
          items.push(item.text.downcase)
        end
        mods["#{categories_index.fetch(index)}"] = items
      end

      item_hash.store('mods', mods) if mods.keys.length > 0

      save_to 'scraped_data.json', item_hash, format: :pretty_json, position: false if item_hash.keys.length > 1 && item_hash["name"] != "weapon mods"
    end
  end
end

TarkovSpider.crawl!
