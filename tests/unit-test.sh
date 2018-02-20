#!/bin/bash
set -x

image_name=${1:? $(basename $0) IMAGE_NAME VERSION needed}
version=${2:-latest}
namespace=gitlab-ce
test_service=gitlab

ret=0
echo "Check tests/docker-compose.yml config"
docker-compose -p ${namespace} config
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] docker-compose -p ${namespace} config"
else
  echo "[FAILED] docker-compose -p ${namespace} config"
  ret=1
fi

echo "Check gitlab installed"
docker-compose -p ${namespace} run --name "test-gitlab" --rm $test_service ls -l /opt/
test_result=$?
if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] gitlab installed"
else
  echo "[FAILED] gitlab installed"
  ret=1
fi

# test a small nginx config
echo "Check gitlab running"

# setup test
echo "# setup env test:"
test_compose=docker-compose.yml
test_service=gitlab
test_config=gitlab-test.sh
docker-compose -p ${namespace} -f $test_compose up -d --no-build $test_service
docker-compose -p ${namespace} -f $test_compose ps $test_service
container=$(docker-compose -p ${namespace}  -f $test_compose ps -q $test_service)
echo docker cp $test_config ${container}:/opt
docker cp $test_config ${container}:/opt

# run test
echo "# run test:"
docker-compose -p ${namespace}  -f $test_compose exec -T $test_service /bin/bash -c "/opt/$test_config"
test_result=$?

# teardown
echo "# teardown:"
docker-compose -p ${namespace}  -f $test_compose stop
docker-compose -p ${namespace}  -f $test_compose rm -fv

if [ "$test_result" -eq 0 ] ; then
  echo "[PASSED] gitlab url check [$test_config]"
else
  echo "[FAILED] gitlab url check [$test_config]"
  ret=1
fi

exit $ret
