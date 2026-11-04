require "rails_helper"

RSpec.describe AuditSeverityGate do
  describe ".blocking?" do
    context "深刻度が High 以上のとき" do
      [ "high", "critical", "HIGH", :critical ].each do |severity|
        it "#{severity.inspect} なら true を返す" do
          expect(described_class.blocking?(severity)).to be true
        end
      end
    end

    context "深刻度が不明（nil・空文字）のとき" do
      [ nil, "" ].each do |severity|
        it "#{severity.inspect} なら true を返す" do
          expect(described_class.blocking?(severity)).to be true
        end
      end
    end

    context "深刻度が知らない値のとき" do
      it "true を返す" do
        expect(described_class.blocking?("severe")).to be true
      end
    end

    context "深刻度が High 未満のとき" do
      [ "low", "medium", "moderate", "none", "info", :low, "LOW" ].each do |severity|
        it "#{severity.inspect} なら false を返す" do
          expect(described_class.blocking?(severity)).to be false
        end
      end
    end
  end
end
