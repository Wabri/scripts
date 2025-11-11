#!/usr/bin/env bash

source test/init
plan tests 11

mock_osc() {
    local cmd=$1
    local args=(${@:2})
    if [[ $cmd == 'request' && ${args[0]} == 'list' ]]; then
        _request_list
    fi
}

_request_list() {
    echo "Created by: foo"
}

mock_git_obs() {
    if [[ $3 == 'repos/pool/openQA/pulls?state=open&sort=recentupdate' ]]; then
        _pr_list leap-16.0
    else
        _pr_list foo # PR targeting "foo" is supposed to be ignored
    fi
}

_pr_list() {
    local ref=$1
    echo "[{\"updated_at\":\"$two_days_ago\", \"html_url\": \"https://foo/bar\", \"user\": {\"login\": \"$git_user\"}, \"base\": {\"ref\": \"$ref\"}}]"
}

two_days_ago=$(date --iso-8601=seconds --date='-2 day')
osc=mock_osc
git_obs=mock_git_obs
source os-autoinst-obs-auto-submit

note "########### has_pending_submission"

throttle_days=0
package=os-autoinst
try has_pending_submission "$package" "$submit_target"
is "$rc" 0 "returns 0 with throttle_days=0"

throttle_days=1
try has_pending_submission "$package" "$submit_target"
is "$rc" 1 "returns 1 with existing SRs"
like "$got" "Created by: foo" "expected output"

_request_list() {
    echo ""
}
try has_pending_submission "$package" "$submit_target"
is "$rc" 0 "returns 0 without existing SRs"
like "$got" "info.*has_pending_submission" "no output"

submit_target=openSUSE:Leap:16.0
try has_pending_submission "$package" "$submit_target"
is "$rc" 0 "returns 0 without existing PRs"
like "$got" "info.*has_pending_submission\\($package, $submit_target\\)$" "no output (no PR)"

package=openQA
try has_pending_submission "$package" "$submit_target"
is "$rc" 0 "returns 0 with existing PR older than throttle config of $throttle_days days"
like "$got" "info.*has_pending_submission\\($package, $submit_target\\)$" "no output (old PR)"

throttle_days=3
try has_pending_submission "$package" "$submit_target"
is "$rc" 1 "returns 1 with existing PR recent than throttle config of $throttle_days days"
like "$got" "info.*Skipping submission.*pending PR.*https://foo/bar" "expected output (recent PR)"
