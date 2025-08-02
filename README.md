# GitHubプロジェクトコピーツール

このツールは、GitHubプロジェクトを別のリポジトリにコピーし、関連するissueも含めて移行するためのシェルスクリプトです。

## 機能

- GitHubプロジェクトの構造をコピー
- プロジェクトカラムの再作成
- 関連するissueのコピー
- プロジェクトメタデータの保持

## 前提条件

1. **jq**コマンドがインストールされている必要があります
   ```bash
   # macOSの場合
   brew install jq
   
   # Ubuntuの場合
   sudo apt-get install jq
   ```

2. **GitHubアクセストークン**が必要です
   - [GitHub Personal Access Token](https://github.com/settings/tokens)を作成
   - **必要な権限（重要）**: 
     - `repo` - リポジトリへのフルアクセス
     - `read:project` - プロジェクトV2の読み取り
     - `write:project` - プロジェクトV2の作成と編集
     - `read:user` - ユーザー情報の読み取り
   
   **トークン作成手順**:
   1. [GitHub設定 > Personal access tokens](https://github.com/settings/tokens)にアクセス
   2. "Generate new token (classic)"をクリック
   3. 上記のスコープを全て選択
   4. トークンを生成してコピー

## 使用方法

### 1. 環境変数の設定

スクリプトを実行する前に、以下の環境変数を設定してください：

```bash
# GitHubの個人アクセストークン
export GITHUB_TOKEN="your_github_token_here"
```

**注意**: 以前のバージョンでは`TARGET_OWNER`と`TARGET_REPO`の設定が必要でしたが、現在のバージョンでは不要です。issueは元のリポジトリに作成され、プロジェクトは元のorganizationに作成されます。

### 2. スクリプトの実行

```bash
./copy_github_project.sh
```

## 設定のカスタマイズ

`copy_github_project.sh`ファイル内の以下の変数を変更することで、異なるプロジェクトをコピーできます：

```bash
# コピー元のプロジェクト設定
SOURCE_PROJECT_URL="https://github.com/users/rei1011/projects/1"
SOURCE_OWNER="rei1011"
SOURCE_PROJECT_ID="1"
```

## 動作の詳細

このスクリプトは以下の処理を順次実行します：

1. **環境設定チェック** - 必要な環境変数とコマンドの確認
2. **プロジェクト情報取得** - ソースプロジェクトの詳細情報を取得
3. **カラム・カード取得** - プロジェクトの構造とカード情報を取得
4. **関連issue取得** - プロジェクトカードからリンクされたissueを特定・取得
5. **コピー先リポジトリ作成** - 必要に応じて新しいリポジトリを作成
6. **issue移行** - 取得したissueを**元のリポジトリ**にコピー（コピー元と同じリポジトリに作成）
7. **プロジェクト作成** - 新しいプロジェクトを作成
8. **カラム再現** - 元のプロジェクトのカラム構造を再現

## 注意事項

- プロジェクトカードの内容（ノートなど）は現在サポートされていません
- プライベートリポジトリのissueをコピーする場合は、適切な権限が必要です
- APIレート制限により、大量のissueがある場合は時間がかかる場合があります
- コピーされたissueには元のプロジェクトへの参照が追加されます

## トラブルシューティング

### よくあるエラー

1. **jqコマンドが見つからない**
   ```
   brew install jq
   ```

2. **GITHUB_TOKEN環境変数が設定されていない**
   ```bash
   export GITHUB_TOKEN="your_token_here"
   ```

3. **権限エラー（INSUFFICIENT_SCOPES）**
   - GitHubトークンに適切な権限が設定されているか確認
   - 必要なスコープ: `repo`, `read:project`, `write:project`, `read:user`
   - エラーメッセージに「read:project」が不足していると表示される場合は、トークンを再作成

4. **プロジェクトが見つからない**
   - `SOURCE_OWNER`と`SOURCE_PROJECT_ID`が正しく設定されているか確認
   - プロジェクトがパブリックアクセス可能かまたは適切な権限があるか確認

## サポートされているGitHubプロジェクトタイプ

- ユーザープロジェクト（`/users/{username}/projects/{id}`）
- Organization プロジェクト（設定を変更することで対応可能）
- リポジトリプロジェクト（設定を変更することで対応可能）

## ライセンス

このスクリプトはMITライセンスの下で提供されています。

## 貢献

バグレポートや機能追加の要望は、GitHubのIssueにお願いします。プルリクエストも歓迎します。
