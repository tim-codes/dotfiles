# Open k9s on one of Tim's clusters, by a short name.
#
#   kk                     pick a cluster in fzf
#   kk home                the home k3s cluster (kube context `home`)
#   kk build               the GKE build cluster (ci-runners, exxo-internal),
#                          the compute Gaia's builders and the ARC runners borrow
#   kk hub                 the GKE fleet-hub cluster (exxo-internal)
#   kk build -c pods       anything after the cluster goes to k9s as-is
#   kk -c pods             no cluster but k9s flags: pick, then pass them on
#
# Fleet naming: sites are home, htz (future) and gke; the GKE clusters are
# build and hub. `homelab` and `buildlab` are transitional aliases for `home`
# and `build`: accepted, but not offered in the picker. Drop them once the
# old names are out of muscle memory.
#
# Always all namespaces (-A) and no splash screen. The context is passed per
# invocation (k9s --context), never selected, so the kubeconfig's current
# context stays whatever it was.
#
# The GKE contexts are created on first use with `gcloud container clusters
# get-credentials`, which would also make them the current context; the
# previous current context is restored straight after. They authenticate with
# your gcloud login through gke-gcloud-auth-plugin, so an expired login means
# `gcloud auth login` first.
#
# home's context is `home`. Until the homelab repo's kubeconfig change lands
# on this machine it may still be called `homelab`; that is used (with a
# note) when `home` is absent.

# Ensure a GKE cluster's kube context exists, adding it if not, and leave the
# current context as it was. Usage: __kk_gke <name> <context> <cluster>
function __kk_gke
    set -l name $argv[1]
    set -l ctx $argv[2]
    set -l cluster $argv[3]
    if not kubectl config get-contexts -o name 2>/dev/null | string match -q -- $ctx
        echo "kk: adding the $name context to your kubeconfig (current context kept)" >&2
        set -l current (kubectl config current-context 2>/dev/null)
        gcloud container clusters get-credentials $cluster \
            --zone europe-west2-a --project exxo-internal >&2
        or begin
            echo "kk: get-credentials failed (gcloud auth login?)" >&2
            return 1
        end
        test -n "$current"; and kubectl config use-context $current >/dev/null
    end
end

function kk -d "k9s on a named cluster (home, build, hub); no cluster picks one; extra args go to k9s"
    set -l names home build hub
    set -l target
    set -l rest $argv

    # A first argument that isn't a flag is the cluster; everything else is k9s's.
    if test (count $argv) -gt 0; and not string match -q -- '-*' $argv[1]
        set target $argv[1]
        set rest $argv[2..-1]
    end

    if test -z "$target"
        if not command -q fzf
            echo "kk: fzf not installed; pass a cluster: kk home|build|hub [k9s args]" >&2
            return 1
        end
        set target (printf '%s\n' $names | fzf --height=~6 --prompt='cluster> ' --no-multi)
        or return 130
    end

    # Transitional aliases for the old names.
    switch $target
        case homelab
            set target home
        case buildlab
            set target build
    end

    set -l ctx
    switch $target
        case home
            set -l contexts (kubectl config get-contexts -o name 2>/dev/null)
            if contains -- home $contexts
                set ctx home
            else if contains -- homelab $contexts
                set ctx homelab
                echo "kk: kube context 'home' not found; using the old 'homelab' (not renamed yet: run `just kubeconfig` in the homelab repo's projects/k8s)" >&2
            else
                echo "kk: no 'home' kube context (nor the old 'homelab'); run `just kubeconfig` in the homelab repo's projects/k8s" >&2
                return 1
            end
        case build
            set ctx gke_exxo-internal_europe-west2-a_ci-runners
            __kk_gke build $ctx ci-runners; or return 1
        case hub
            set ctx gke_exxo-internal_europe-west2-a_fleet-hub
            __kk_gke hub $ctx fleet-hub; or return 1
        case '*'
            echo "kk: unknown cluster '$target' (one of: $names)" >&2
            return 2
    end

    # Title the pane after the resolved cluster (the picker leaves fish's own
    # title at just "kk"); same shape as fish_title, which tmux shows as #T.
    # fish puts its usual title back when k9s exits.
    if isatty stdout
        printf '\e]2;%s\a' (fish_prompt_pwd_dir_length=1 prompt_pwd)": "(string join -- " " kk $target $rest)
    end

    k9s -A --splashless --context $ctx $rest
end
