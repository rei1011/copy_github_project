#!/bin/bash

# GitHubプロジェクトコピーツールの使用例
# このスクリプトは使用方法の例を示します

echo "GitHubプロジェクトコピーツール - 使用例"
echo "========================================="
echo

echo "1. 環境変数の設定例:"
echo "export GITHUB_TOKEN=\"ghp_your_token_here\""
echo "export TARGET_OWNER=\"your_username\""
echo "export TARGET_REPO=\"copied_project\""
echo

echo "2. スクリプト実行:"
echo "./copy_github_project.sh"
echo

echo "3. 設定確認:"
echo "環境変数が正しく設定されているか確認:"
echo "echo \$GITHUB_TOKEN"
echo "echo \$TARGET_OWNER"
echo "echo \$TARGET_REPO"
echo

echo "4. jqのインストール確認:"
echo "which jq"
echo "jq --version"
echo

echo "注意: 実際にスクリプトを実行する前に、上記の環境変数を設定してください。"
