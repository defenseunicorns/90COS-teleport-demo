cat << EOF > ./aws_auth.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::$TF_VAR_account_id:role/eksctl-teleport-demo-cluster-ServiceRole-XXX
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - userarn: arn:aws:iam::$TF_VAR_account_id:user/megan.wolf
      username: megan.wolf
      groups:
        - system:masters
EOF

kubectl apply -f ./aws_auth.yaml