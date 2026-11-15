import { Controller } from "@hotwired/stimulus"

// 招待リンクなどの文字列をクリップボードにコピーする
//
//   <div data-controller="clipboard">
//     <input data-clipboard-target="source" value="..." readonly>
//     <button data-clipboard-target="button" data-action="clipboard#copy">コピー</button>
//     <span class="visually-hidden" role="status" aria-live="polite" data-clipboard-target="status"></span>
//   </div>
export default class extends Controller {
  static targets = ["source", "button", "status"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value)
      this.showResult("コピーしました")
    } catch {
      // http で開いた場合（navigator.clipboard がない）や権限で拒否された場合は、
      // 入力欄を選択して手動でコピーできるようにし、そのことをボタンの文言で伝える
      this.sourceTarget.select()
      this.showResult("選択したリンクを手動でコピーしてください")
    }
  }

  // ボタンの文言を変え、読み上げソフト向けの live region（status ターゲット。なくてもよい）にも同じ文言を入れる
  showResult(message) {
    this.buttonTarget.textContent = message
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
