module ApplicationHelper
  # URL として扱う文字。ASCII だけにして「https://example.comおすすめ」のように日本語が続いても URL がそこで終わるようにする。
  # 「(」「)」は文章の括弧と区別できないため含めない。
  # 「https://example.com.」のように末尾に付いた句読点（. , ! ? ; : '）は文章の一部とみなし、URL に含めない。
  URL_PATTERN = %r{https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'*+,;=%]+(?<![.,!?;:'])}
  # 文字列全体が URL かどうかを判定する
  EXACT_URL_PATTERN = /\A#{URL_PATTERN}\z/

  # simple_form_for の defaults: { label_text: } に渡し、必須バッジなしのラベルにする。
  # ログイン・サインアップでは必須バッジを表示しない仕様のため（HTML の required 属性は残る）。
  def label_text_without_required_mark
    ->(label, _required, _explicit_label) { label }
  end

  # テキスト中の URL を新しいタブで開くリンクにする。URL 以外の部分は HTML エスケープする
  def link_urls(text)
    parts = text.to_s.split(/(#{URL_PATTERN})/o)
    safe_join(parts.map do |part|
      part.match?(EXACT_URL_PATTERN) ? link_to(part, part, target: "_blank", rel: "noopener noreferrer") : part
    end)
  end
end
