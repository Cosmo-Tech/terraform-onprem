#!/bin/sh


# Stop script if missing dependency
required_commands="kubeadm kubectl"
for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
        echo "error: required command not found: $command"
        exit 1
    fi
done



# Create a Kubedam node (= join existing Kubeadm controlplane)
# Usage: join_controlplane
join_controlplane() {
  echo "todo"
}

join_controlplane


exit
