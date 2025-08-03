#!/bin/bash

# GitHubプロジェクトコピースクリプト
# 使用方法: ./copy_github_project.sh

set -e

# 設定変数
SOURCE_OWNER="copy-project"
SOURCE_PROJECT_ID="1"

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 必要な変数、コマンドが利用可能であるか確認
check_requirements() {
    
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_TOKEN環境変数が設定されていません"
        echo "GitHubの個人アクセストークンを設定してください:"
        echo "export GITHUB_TOKEN=your_token_here"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curlコマンドが見つかりません"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jqコマンドが見つかりません。インストールしてください: brew install jq"
        exit 1
    fi
}

# GraphQL APIを呼び出すための関数
# Projects v2 はGraphQLでのみ操作可能なので、GraphQLを使用
github_graphql() {
    local query="$1"
    local variables="$2"
    
    # クエリの改行と余分なスペースを削除
    local clean_query=$(echo "$query" | tr -d '\n' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    
    local data=$(jq -n \
        --arg query "$clean_query" \
        --arg variables "$variables" \
        '{
            query: $query,
            variables: ($variables | fromjson)
        }')
    
    curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$data" \
        "https://api.github.com/graphql"
}

# GitHub APIを呼び出すための関数
# Projects v2以外の操作はREST APIの方がシンプルなのでこちらを使用
github_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local curl_args=(
        -s
        -H "Authorization: token $GITHUB_TOKEN"
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28"
        -X "$method"
    )
    
    if [ -n "$data" ]; then
        curl_args+=(-H "Content-Type: application/json" -d "$data")
    fi
    
    curl "${curl_args[@]}" "https://api.github.com/$endpoint"
}

# プロジェクト情報を取得
get_project_info() {
    log_info "プロジェクト情報を取得しています..."
    
    # GraphQLクエリでユーザーまたはOrganizationのプロジェクトを取得
    # 流石にissueが100件を超えることはないはずなので、first: 100で十分
    local query='
    query($login: String!, $projectNumber: Int!) {
        organization(login: $login) {
            projectV2(number: $projectNumber) {
                id
                title
                items(first: 100) {
                    nodes {
                        id
                        content {
                            __typename
                            ... on Issue {
                                id
                                title
                                body
                                repository {
                                    name
                                    owner {
                                        login
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }'
    
    local variables=$(jq -n \
        --arg login "$SOURCE_OWNER" \
        --arg projectNumber "$SOURCE_PROJECT_ID" \
        '{
            login: $login,
            projectNumber: ($projectNumber | tonumber)
        }')
    
    local response=$(github_graphql "$query" "$variables")
    
    # レスポンスをデバッグ出力
    echo "$response" | jq . > debug_projects.json
    
    # エラーチェック
    local errors=$(echo "$response" | jq '.errors // empty')
    if [ -n "$errors" ] && [ "$errors" != "null" ]; then
        log_error "GraphQLクエリでエラーが発生しました:"
        echo "$errors" | jq .
        exit 1
    fi
    
    # プロジェクト情報を抽出
    local project_data=$(echo "$response" | jq '.data.organization.projectV2')
    
    if [ "$project_data" = "null" ] || [ -z "$project_data" ]; then
        log_error "プロジェクト番号 $SOURCE_PROJECT_ID が見つかりません"
        log_info "プロジェクトが存在するか、アクセス権限があるか確認してください"
        exit 1
    fi
    
    PROJECT_NAME=$(echo "$project_data" | jq -r '.title')
    
    # issueを保存
    echo "$project_data" | jq '.items.nodes' > project_items.json
    
    log_success "プロジェクト情報を取得しました: $PROJECT_NAME"
}


# 関連するissueを取得
get_related_issues() {
    log_info "issueを取得しています..."
    
    if [ ! -f "project_items.json" ]; then
        log_error "project_items.json ファイルが見つかりません"
        exit 1
    fi
    
    # プロジェクトアイテムからissueを抽出
    echo "[]" > issues.json
    jq -c '.[] | select(.content != null)' project_items.json | while read -r item; do
        local content_type=$(echo "$item" | jq -r '.content.__typename // "unknown"')
        
        # Issue タイプをチェック
        if [[ "$content_type" == "Issue" ]]; then
            local issue_content=$(echo "$item" | jq '.content')
            local title=$(echo "$issue_content" | jq -r '.title // "タイトルなし"')
            local body=$(echo "$issue_content" | jq -r '.body // ""')
            local repo_name=$(echo "$issue_content" | jq -r '.repository.name // "不明"')
            local repo_owner=$(echo "$issue_content" | jq -r '.repository.owner.login // "不明"')
            
            log_info "Issue を処理中: $title ($repo_owner/$repo_name)"
            
            # issue情報をJSONとして構築
            local issue_json=$(jq -n \
                --arg title "$title" \
                --arg body "$body" \
                --arg repo_name "$repo_name" \
                --arg repo_owner "$repo_owner" \
                '{
                    title: $title,
                    body: $body,
                    repository: {
                        name: $repo_name,
                        owner: {login: $repo_owner}
                    }
                }')
            
            # 既存のissues.jsonに追加
            local temp_file=$(mktemp)
            jq ". += [$issue_json]" issues.json > "$temp_file" && mv "$temp_file" issues.json
        fi
    done
    
    local issue_count=$(jq '. | length' issues.json)
    log_success "$issue_count 個のissueを取得しました"
    
    # デバッグ情報を保存
    cp issues.json issues_debug.json
}


# issueをコピー
copy_issues() {
    log_info "issueをリポジトリにコピーしています..."
    
    local issue_count=$(jq '. | length' issues.json)
    
    if [ "$issue_count" -eq 0 ]; then
        log_warning "コピーするissueがありません"
        return
    fi

    
    # jqの出力を配列に読み込む
    local created_issues=()
    while IFS= read -r issue; do
        local title=$(echo "$issue" | jq -r '.title')
        local body=$(echo "$issue" | jq -r '.body // ""')
        local repo_owner=$(echo "$issue" | jq -r '.repository.owner.login // ""')
        local repo_name=$(echo "$issue" | jq -r '.repository.name // ""')
        
        # リポジトリ情報が取得できない場合はスキップ
        if [ -z "$repo_owner" ] || [ -z "$repo_name" ] || [ "$repo_owner" = "null" ] || [ "$repo_name" = "null" ]; then
            log_warning "Issue \"$title\" のリポジトリ情報が不完全です。スキップします。"
            continue
        fi
        
        log_info "Issue \"$title\" を $repo_owner/$repo_name にコピー中..."
        
        # 本文に元のプロジェクトへの参照を追加
        local new_body="$body"
        
        local issue_data=$(jq -n \
            --arg title "$title" \
            --arg body "$new_body" \
            '{
                title: $title,
                body: $body
            }')
        
        # 元のリポジトリにissueを作成
        local create_response=$(github_api "repos/$repo_owner/$repo_name/issues" "POST" "$issue_data")
        
        if echo "$create_response" | jq -e '.number' > /dev/null; then
            local new_issue_number=$(echo "$create_response" | jq -r '.number')
            local new_issue_id=$(echo "$create_response" | jq -r '.node_id')
            log_success "Issue #$new_issue_number を $repo_owner/$repo_name に作成しました: $title"
            created_issues+=("$new_issue_id")
        else
            log_error "Issue \"$title\" の $repo_owner/$repo_name への作成に失敗しました"
            echo "$create_response" | jq .
        fi
    done < <(jq -c '.[]' issues.json)
    
    # 作成されたissueのIDを保存
    printf '%s\n' "${created_issues[@]}" > created_issues_ids.txt
    
    log_success "issueを元のリポジトリにコピーしました"
}

# 新しいプロジェクトを作成（GraphQL使用）
create_target_project() {
    log_info "新しいプロジェクトを作成しています..."
    
    # OrganizationのIDを取得
    local org_info=$(github_api "orgs/$SOURCE_OWNER")
    local org_id=$(echo "$org_info" | jq -r '.node_id')
    
    if [ "$org_id" = "null" ] || [ -z "$org_id" ]; then
        log_error "Organization ID の取得に失敗しました"
        exit 1
    fi
    
    # Organizationレベルプロジェクト用のGraphQLミューテーション
    local mutation='
    mutation($ownerId: ID!, $title: String!) {
        createProjectV2(input: {
            ownerId: $ownerId,
            title: $title
        }) {
            projectV2 {
                id
                title
            }
        }
    }'
    
    local variables=$(jq -n \
        --arg ownerId "$org_id" \
        --arg title "$PROJECT_NAME copy" \
        '{
            ownerId: $ownerId,
            title: $title
        }')
    
    local response=$(github_graphql "$mutation" "$variables")
    
    # エラーチェック
    local errors=$(echo "$response" | jq '.errors // empty')
    if [ -n "$errors" ] && [ "$errors" != "null" ]; then
        log_error "プロジェクトの作成でエラーが発生しました:"
        echo "$errors" | jq .
        exit 1
    fi
    
    local project_data=$(echo "$response" | jq '.data.createProjectV2.projectV2')
    
    if [ "$project_data" = "null" ] || [ -z "$project_data" ]; then
        log_error "プロジェクトの作成に失敗しました"
        exit 1
    fi
    
    TARGET_PROJECT_ID=$(echo "$project_data" | jq -r '.id')
    local project_title=$(echo "$project_data" | jq -r '.title')
    
    log_success "プロジェクトを作成しました: $project_title"
}

# プロジェクトにissueを追加
create_project_columns() {
    log_info "新しく作成したissueのみをプロジェクトに追加しています..."
    
    if [ ! -f "created_issues_ids.txt" ]; then
        log_warning "created_issues_ids.txt が見つかりません。issueの追加をスキップします。"
        return
    fi

    
    # 作成されたissueのIDを使用してプロジェクトに追加
    cat created_issues_ids.txt | while IFS= read -r issue_id; do
        if [ -n "$issue_id" ]; then
            log_info "新しく作成されたissue (ID: $issue_id) をプロジェクトに追加中..."
            
            # プロジェクトにアイテムを追加するGraphQLミューテーション
            local add_mutation='
            mutation($projectId: ID!, $contentId: ID!) {
                addProjectV2ItemById(input: {
                    projectId: $projectId,
                    contentId: $contentId
                }) {
                    item {
                        id
                    }
                }
            }'
            
            local add_variables=$(jq -n \
                --arg projectId "$TARGET_PROJECT_ID" \
                --arg contentId "$issue_id" \
                '{
                    projectId: $projectId,
                    contentId: $contentId
                }')
            
            local add_response=$(github_graphql "$add_mutation" "$add_variables")
            
            # エラーチェック
            local add_errors=$(echo "$add_response" | jq '.errors // empty')
            if [ -n "$add_errors" ] && [ "$add_errors" != "null" ]; then
                log_warning "Issue (ID: $issue_id) のプロジェクトへの追加に失敗しました:"
                echo "$add_errors" | jq .
            else
                log_success "Issue (ID: $issue_id) をプロジェクトに追加しました"
            fi
        fi
    done
    
    log_success "新しく作成されたissueをプロジェクトに追加しました"
}

# 一時ファイルをクリーンアップ
cleanup() {
    log_info "一時ファイルをクリーンアップしています..."
    rm -f project_columns.json column_*_cards.json issue_urls.txt issues.json debug_*.json project_items.json items_debug.txt issues_debug.json created_issues_ids.txt
    log_success "クリーンアップが完了しました"
}

# メイン処理
main() {
    log_info "GitHubプロジェクトコピーを開始します"
    
    check_requirements
    get_project_info
    get_related_issues
    copy_issues
    create_target_project
    create_project_columns
    cleanup
    
    log_success "プロジェクトのコピーが完了しました"
}

# スクリプト実行
main "$@"
