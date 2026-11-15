import { Controller } from "@hotwired/stimulus"

// 招待リンクなどの文字列をクリップボードにコピーする
//
//   <div data-controller="clipboard">
//     <input data-clipboard-target="source" value="..." readonly>
//     <button data-clipboard-target="button" data-action="clipboard#copy">コピー</button>
//   </div>
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.buttonTarget.textContent = "コピーしました"
    } catch {
      // http で開いた場合（navigator.clipboard がない）や権限で拒否された場合は、
      // 入力欄を選択して手動でコピーできるようにする
      this.sourceTarget.select()
    }
  }
}
