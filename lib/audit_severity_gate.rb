# CI の脆弱性チェック（bin/bundler-audit-gate, bin/importmap-audit-gate）で、
# 深刻度から「CI を失敗させるか」を判定する。
# bin スクリプトから require_relative で読むため、Rails に依存しない素の Ruby で書く。
module AuditSeverityGate
  # High 未満として成功させる深刻度。これ以外（high / critical、nil・空文字、知らない値）はすべて失敗させる
  NON_BLOCKING_SEVERITIES = %w[none info low medium moderate].freeze

  def self.blocking?(severity)
    !NON_BLOCKING_SEVERITIES.include?(severity.to_s.strip.downcase)
  end
end
