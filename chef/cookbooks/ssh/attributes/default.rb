#
# Cookbook Name:: ssh
# Attributes:: default
#
# Author:: Waldemar Hummer
#

set['ssh']['public_key'] = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKiY5q92B4NTGL+dID961Zjq3Z5RlhcvbBheoh23MqAQFbI2uG+5TCp9EZrI6/3/i7CSl9sVtu7a1TWmKqKsZFaxB4Y45rL/5xTAJ63CCGwMlTMcLemQ+opcErsyCtPbdkXXKJciQf88V5KQG/AOcNvpbfU0HN3CF+BkrNAiw0vyiOheL9UBAcNYLmcn9PbGmsIcRDfrjXi1uPSmS2LpUp0hu6xaSMnTbF+kkXFa0WKheunZozuPuuRrhS8vm/toGTr3F+fi18Fi9oIfZ22rQUx+M737RkiT00gqzTq/6CQnsOzOeASOcRAa2xkwSs2SovjnrFmjiKu4zzuhmPJjkv"
default['ssh']['config_dir'] = "#{(`bash -c 'echo $HOME'`).strip}/.ssh"

