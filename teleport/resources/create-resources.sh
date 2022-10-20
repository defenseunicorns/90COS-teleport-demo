cat << EOF > ./token.yaml
# token.yaml
kind: token
version: v2
metadata:
  # the token name is not a secret because instances must prove that they are
  # running in your AWS account to use this token
  name: ec2-token
  # set a long expiry time, the default for tokens is only 30 minutes
  expires: "3000-01-01T00:00:00Z"
spec:
  # use the minimal set of roles required
  roles: [Node]

  # set the join method allowed for this token
  join_method: ec2

  # aws_iid_ttl is the amount of time after the EC2 instance is launched during
  # which it should be allowed to join the cluster. Use a short TTL to decrease
  # the risk of stolen EC2 Instance Identity Documents being used to join your
  # cluster.
  #
  # When launching your first Node using the EC2 join method, you may need to
  # temporarily configure a higher `aws_iid_ttl` value so that you have time
  # to get Teleport set up and configured. This feature works best once Teleport
  # is configured in an EC2 AMI to start automatically on launch.
  aws_iid_ttl: 5m

  allow:
  - aws_account: "$TF_VAR_account_id" # your AWS account ID
    aws_regions: # use the minimal set of AWS regions required
    - us-east-1
EOF

tctl create -f ./roles.yaml
tctl create -f ./users.yaml
tctl create -f ./token.yaml