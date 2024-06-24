if [ -z "$1" ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

_template_sub_path=".spec.template" # yaml sub path to spec.template

if grep -q "kind: Deployment" $1; then
    _template_sub_path=".spec.template"
elif grep -q "kind: CronJob" $1; then
    _template_sub_path=".spec.jobTemplate.spec.template"
else
    echo "Error: no spec.template or spec.jobTemplate.spec.template found in $1"
    exit 1
fi

docker_compose_starter="""#Generated Docker-Compose file from Kuberneted Deployment/CronJob file: $1
version: '3.4'
services:
  application:
    image: application
    build:
      context: .
      dockerfile: ./Dockerfile
    container_name: application
"""

echo "$docker_compose_starter" >temp.yml

# Extracting the container environement variables
for env in $(yq "$_template_sub_path.spec.containers.[].env.[].name" $1); do
    value="\${$env}" yq eval -i ".services.application.environment.$env = strenv(value)" temp.yml
done

# Extracting the container ports
for prt in $(yq "$_template_sub_path.spec.containers.[].ports.[].containerPort" $1); do
    value="$prt:$prt" yq eval -i ".services.application.ports += [strenv(value)]" temp.yml
done

for vlm in $(yq "$_template_sub_path.spec.containers.[].volumeMounts.[].mountPath" $1); do
    value="\${LOCAL_MOUNT_PATH}:$vlm" yq eval -i ".services.application.volumes += [strenv(value)]" temp.yml
done

application_name=$(yq ".metadata.name" $1)
sed "s/application/$application_name/g" temp.yml >temp2.yml &&
    mv temp2.yml docker-compose.yml &&
    rm temp.yml
