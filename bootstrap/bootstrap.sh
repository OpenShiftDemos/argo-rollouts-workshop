# A shell script for bootstrapping the demo into an RHDP cluster
# This will not be needed with agnosticv/agnosticd but here as a
# starting point
#
# Script requirements:
#   Must be logged in as cluster-admin
#   Must have `envsubst` installed

#!/bin/bash

LANG=C
SLEEP_SECONDS=45

echo ""
echo "Installing GitOps Operator."

kustomize build infra/components/gitops-operator/operator/base | oc apply -f -

echo "Pause $SLEEP_SECONDS seconds for the creation of the gitops-operator..."
sleep $SLEEP_SECONDS

echo "Waiting for operator to start"
until oc get deployment gitops-operator-controller-manager -n openshift-operators
do
  sleep 5;
done

echo "Waiting for openshift-gitops namespace to be created"
until oc get ns openshift-gitops
do
  sleep 5;
done

echo "Waiting for deployments to start"
until oc get deployment cluster -n openshift-gitops
do
  sleep 5;
done

echo "Waiting for all pods to be created"
deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n openshift-gitops
done

echo "Fetching cluster subdomain"
export SUB_DOMAIN=$(oc get ingress.config.openshift.io cluster -n openshift-ingress -o jsonpath='{.spec.domain}')
echo "SUB_DOMAIN=${SUB_DOMAIN}"

echo "Apply overlay to override default instance"
# echo "Create default instance of gitops operator"
kustomize build infra/components/gitops-operator/instance/base | envsubst '${SUB_DOMAIN}' | oc apply -f -

sleep 10
echo "Waiting for all pods to redeploy"
deployments=(cluster kam openshift-gitops-applicationset-controller openshift-gitops-redis openshift-gitops-repo-server openshift-gitops-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n openshift-gitops
done

echo "GitOps Operator ready"

# echo "Adding bootstrap app-of-app"
# oc apply -k bootstrap/argo/base
