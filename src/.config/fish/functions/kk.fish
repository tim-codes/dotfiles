# Open k9s on one of Tim's clusters, by a short name.
#
#   kk              pick a cluster in fzf
#   kk homelab      the homelab k3s cluster (kube context `homelab`)
#   kk buildlab     the buildlab GKE cluster (ci-runners, exxo-internal), the
#                   compute Gaia's builders and the ARC runners borrow
#
# Always all namespaces (-A) and no splash screen. The context is passed per
# invocation (k9s --context), never selected, so the kubeconfig's current
# context stays whatever it was.
#
# buildlab's context is created on first use with `gcloud container clusters
# get-credentials`, which would also make it the current context; the previous
# current context is restored straight after. It authenticates with your gcloud
# login through gke-gcloud-auth-plugin, so an expired login means
# `gcloud auth login` first.
function kk -d "k9s on a named cluster (homelab, buildlab); no argument picks one"
    set -l names homelab buildlab
    set -l target $argv[1]

    if test (count $argv) -gt 1
        echo "usage: kk [homelab|buildlab]" >&2
        return 2
    end

    if test -z "$target"
        if not command -q fzf
            echo "kk: fzf not installed; pass a cluster: kk homelab|buildlab" >&2
            return 1
        end
        set target (printf '%s\n' $names | fzf --height=~6 --prompt='cluster> ' --no-multi)
        or return 130
    end

    set -l ctx
    switch $target
        case homelab
            set ctx homelab
        case buildlab
            set ctx gke_exxo-internal_europe-west2-a_ci-runners
            if not kubectl config get-contexts -o name 2>/dev/null | string match -q -- $ctx
                echo "kk: adding the buildlab context to your kubeconfig (current context kept)" >&2
                set -l current (kubectl config current-context 2>/dev/null)
                gcloud container clusters get-credentials ci-runners \
                    --zone europe-west2-a --project exxo-internal >&2
                or begin
                    echo "kk: get-credentials failed (gcloud auth login?)" >&2
                    return 1
                end
                test -n "$current"; and kubectl config use-context $current >/dev/null
            end
        case '*'
            echo "kk: unknown cluster '$target' (one of: $names)" >&2
            return 2
    end

    k9s -A --splashless --context $ctx
end
