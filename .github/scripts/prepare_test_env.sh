#!/usr/bin/env bash
# Claude Code Action 用: rspec などのチェックに必要な重い準備をまとめたもの
# 質問だけのときは実行せず、コードを変更してチェックする前に Claude が実行する
set -euo pipefail

sudo apt-get update
sudo apt-get install --no-install-recommends -y libvips

yarn install --frozen-lockfile
yarn build:css

bin/rails db:test:prepare
