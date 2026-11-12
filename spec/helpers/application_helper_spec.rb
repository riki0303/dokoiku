require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#link_urls" do
    # 変換結果を HTML として読み、a タグを返す
    def links_in(text)
      Nokogiri::HTML.fragment(helper.link_urls(text)).css("a")
    end

    it "URL を新しいタブで開くリンクにすること" do
      link = links_in("https://example.com/menu").first
      expect(link.to_h).to include("href" => "https://example.com/menu", "target" => "_blank", "rel" => "noopener noreferrer")
    end

    it "URL の前後の文章をそのまま残すこと" do
      html = Nokogiri::HTML.fragment(helper.link_urls("ここ https://example.com が気になる"))
      expect(html.text).to eq("ここ https://example.com が気になる")
    end

    it "URL が複数あればそれぞれリンクにすること" do
      links = links_in("http://a.example.com と https://b.example.com/?q=1")
      expect(links.map { |a| a["href"] }).to eq(%w[http://a.example.com https://b.example.com/?q=1])
    end

    it "URL のすぐあとに日本語が続いても、URL はそこで終わること" do
      expect(links_in("https://example.comおすすめ").map { |a| a["href"] }).to eq(%w[https://example.com])
    end

    it "URL 以外の HTML をエスケープすること", :aggregate_failures do
      result = helper.link_urls("<script>alert(1)</script>")
      expect(result).to eq("&lt;script&gt;alert(1)&lt;/script&gt;")
      expect(result).to be_html_safe
    end

    it "javascript: で始まる文字列はリンクにしないこと" do
      expect(links_in("javascript:alert(1)")).to be_empty
    end

    it "URL がなければ文章をそのまま返すこと" do
      expect(helper.link_urls("夕日を見に行きたい")).to eq("夕日を見に行きたい")
    end

    it "URL の末尾に付いた「.」「,」はリンクに含めず、文章として残すこと", :aggregate_failures do
      result = helper.link_urls("見て https://example.com. と https://example.org, ほか")
      expect(Nokogiri::HTML.fragment(result).css("a").map { |a| a["href"] }).to eq(%w[https://example.com https://example.org])
      expect(Nokogiri::HTML.fragment(result).text).to eq("見て https://example.com. と https://example.org, ほか")
    end

    it "クエリの「&」をエスケープしたうえでリンクにすること", :aggregate_failures do
      result = helper.link_urls("https://example.com/?a=1&b=2")
      expect(result).to include('href="https://example.com/?a=1&amp;b=2"')
      expect(links_in("https://example.com/?a=1&b=2").first["href"]).to eq("https://example.com/?a=1&b=2")
    end

    it "URL のすぐあとの「。」はリンクに含めないこと" do
      expect(links_in("https://example.com。").map { |a| a["href"] }).to eq(%w[https://example.com])
    end

    it "URL を囲む括弧はリンクに含めないこと", :aggregate_failures do
      html = Nokogiri::HTML.fragment(helper.link_urls("(https://example.com)"))
      expect(html.css("a").map { |a| a["href"] }).to eq(%w[https://example.com])
      expect(html.text).to eq("(https://example.com)")
    end

    it "nil なら空文字を返すこと" do
      expect(helper.link_urls(nil)).to eq("")
    end
  end
end
