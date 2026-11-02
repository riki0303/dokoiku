module ApplicationHelper
  # simple_form_for の defaults: { label_text: } に渡し、必須バッジなしのラベルにする。
  # ログイン・サインアップでは必須バッジを表示しない仕様のため（HTML の required 属性は残る）。
  def label_text_without_required_mark
    ->(label, _required, _explicit_label) { label }
  end
end
