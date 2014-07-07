
################################################################################
# (c) Waldemar Hummer
################################################################################

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

module Toaster

  class Docker

    def self.save_container_changes(lxc_name, repository="prototypes")
      oldImgID=`cat /lxc/#{lxc_name}/docker.image.id 2> /dev/null`
      oldImgID = oldImgID.strip
      if oldImgID != ""
        # get existing container ID
        instID=`cat /lxc/#{lxc_name}/docker.container.id`
        instID = instID.strip
        # save container with the new changes
        puts "DEBUG: Committing container changes using command: docker commit #{instID} #{repository} #{lxc_name}"
        newImgID=`docker commit #{instID} #{repository} #{lxc_name}`
        newImgID = newImgID.strip
        images = `docker images | grep -v REPOSITORY | grep #{repository} | grep "#{lxc_name}"`
        images = images.strip.split("\n")
        puts "DEBUG: existing docker images for name '#{lxc_name}' (old image ID '#{oldImgID}'): #{images}"
        if images.size > 1
          # remove old docker image
          `docker rmi #{oldImgID}`
          # update new image id
          `echo #{newImgID} > /lxc/#{lxc_name}/docker.image.id`
        end
      else
        puts "WARN: Could not save container changes. Container image file empty: /lxc/#{lxc_name}/docker.image.id"
      end
    end

    def self.get_container_names()
      result = []
      docker_containers = `docker ps | grep prototypes: | awk '{print $1}'`.strip.split("\n")
      all_cont_id_files = `find /lxc/ -maxdepth 2 -name "docker.container.id"`.strip.gsub(/\n/, " ")
      docker_containers.each do |docker_cont|
        cont_id_files = `grep -l -R "#{docker_cont}" #{all_cont_id_files}`.strip.split("\n")
        cont_id_files.each do |cont_id_file|
          cont_id_file = cont_id_file.gsub(/\/lxc\/([^\/]+)\/.*/, '\1')
          result << cont_id_file
        end
      end
      return result
    end

    def self.kill_container(lxc_name)
      container_id = `cat /lxc/#{lxc_name}/docker.container.id 2> /dev/null`
      container_id = container_id.strip
      puts "DEBUG: Killing docker container ID '#{container_id}'"
      if container_id != ""
        `docker kill #{container_id} 2> /dev/null`
        `docker rm #{container_id} 2> /dev/null`
      else
        puts "WARN: Could not find valid docker container ID in file /lxc/#{lxc_name}/docker.container.id"
      end
    end

    private

    def initialize
    end

  end
end
