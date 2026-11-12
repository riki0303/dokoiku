Rails.application.routes.draw do
  devise_for :users

  resources :places, only: %i[index new create edit update destroy] do
    # 訪問の記録は場所ごとに付けるため、場所の下に置く
    resources :visits, only: %i[new create]
  end
  # 訪問記録の一覧と取り消しは、場所をまたいで扱う
  resources :visits, only: %i[index destroy]
  # 今日決める画面は root で表示する。ここでは「別の3件」だけを生やす
  resource :decision, only: [] do
    post :redraw
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # ホーム画面に追加できるよう、app/views/pwa/manifest.json.erb を返す（application.html.haml でリンクしている）
  # service worker はオフライン対応が必要になるまで無効のままにする
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "decisions#show"
end
