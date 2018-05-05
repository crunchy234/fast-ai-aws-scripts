#! /bin/bash
# Note: The AMI ID assumes you are in the Sydney region to find your image ID search for fastai on aws or see: https://github.com/reshamas/fastai_deeplearn_part1/blob/master/tools/aws_ami_gpu_setup.md
imageId="ami-39ec055b"

# Get this files directory
get_script_dir () {
     SOURCE="${BASH_SOURCE[0]}"
     # While $SOURCE is a symlink, resolve it
     while [ -h "$SOURCE" ]; do
          DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
          SOURCE="$( readlink "$SOURCE" )"
          # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve it relative to the symlink base directory
          [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
     done
     DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
     echo "$DIR"
}

instanceUrlFile="$(get_script_dir)/instanceUrl-$imageId.txt"

bash $(get_script_dir)/setup_container.sh $imageId

instanceUrl=$(cat $instanceUrlFile)

echo Update git repo and Anaconda env
# Don't worry about the host identification key
ssh -oStrictHostKeyChecking=no -i ~/.ssh/aws-key.pem ubuntu@$instanceUrl "export PATH=~/src/anaconda3/bin:\$PATH ; source activate fastai; cd /home/ubuntu/fastai ; git pull; conda env update"
