require 'kimurai'
require 'nokogiri'

class TarkovSpider < Kimurai::Base
  @name = 'tarkov_spider'
  @engine = :mechanize
  @start_urls = ['https://escapefromtarkov.fandom.com/wiki/Weapon_mods']
  @config = {
    retry_request_errors: [{ error: RuntimeError, skip_on_failure: false }]
  }

  def parse(response, url:, data: {})
    #links = getLinks(response)
    links = ['/wiki/KAC_QDC_5.56x45_3-Prong_Flash_Eliminator']
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
        
        compatibles = []
        doc.css('div.wds-tab__content.wds-is-current p a').each do |compatible|
          compatibles.push(compatible.text.downcase)
        end

        attachment_points = []
        doc.css('div.wds-tabs__wrapper.with-bottom-border ul li div a').each do |attachment_point|
          attachment_points.push(attachment_point.text.downcase) if attachment_point.text.downcase != "compatibility"
        end

        if compatibles.length > 0
          item_hash.store('compatible_with', compatibles)
        end

        if attachment_points.length > 0
          item_hash.store('attachment_points', attachment_points)
        end
      end

      save_to 'scraped_data.json', item_hash, format: :pretty_json, position: false if item_hash.keys.length > 1
    end
  end
end

TarkovSpider.crawl!
