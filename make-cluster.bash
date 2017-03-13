#!/bin/bash

source $1

#KILL ALL RUNNING INSTANCES
for k in $(seq 0 $((${#NODE_ADDRESS[@]}-1))); do
    ssh $USERNAME@${NODE_ADDRESS[$k]} "killall beam.smp"
    scp "riak.conf.orig" $USERNAME@${NODE_ADDRESS[$k]}:"${RIAK_CONF_DIR[$k]}/"
done

#SET CONFIGURATION FILES AND START RIAK
for k in $(seq 0 $((${#NODE_ADDRESS[@]}-1))); do
        replace_node_name="sed -i.tmp 's/riak@/${NODE_NAME[$k]}"@"/' ${RIAK_CONF_DIR[$k]}/$FILENAME"
        #replace_node_cookie="sed -i.tmp 's/distributed_cookie = riak/distributed_cookie = ${NODE_NAME[$k]}/' ${RIAK_CONF_DIR[$k]}/$FILENAME"
        replace_node_address="sed -i.tmp 's/127.0.0.1/${NODE_ADDRESS[$k]}/' ${RIAK_CONF_DIR[$k]}/$FILENAME"
        replace_pb_port="sed -i.tmp 's/8087/${PB_PORT[$k]}/' ${RIAK_CONF_DIR[$k]}/$FILENAME"
        replace_http_port="sed -i.tmp 's/8098/${HTTP_PORT[$k]}/' ${RIAK_CONF_DIR[$k]}/$FILENAME"
        append_handoff="echo \"handoff.port = ${HANDOFF_PORT[$k]}\" >> ${RIAK_CONF_DIR[$k]}/$FILENAME"
        start_riak="ulimit -n 65536 && "${RIAK_BIN[$k]}"riak start"
        re_ip="${RIAK_BIN[$k]}riak-admin reip riak@127.0.0.1 "${NODE_NAME[$k]}"@"${NODE_ADDRESS[$k]}
        re_ip=true
		cmd=$replace_node_name" && "$replace_node_address" && "$replace_pb_port" && "$replace_http_port" && "$append_handoff" && "$re_ip" && "$start_riak
		echo "CONFIGURING ${NODE_ADDRESS[$k]}"
		ssh $USERNAME@${NODE_ADDRESS[$k]} $cmd
	done

sleep 15

#JOIN NODES AND COMMIT
for k in $(seq 1 $((${#NODE_ADDRESS[@]}-1))); do
	if [ $k -le 1 ]; then
		continue
	else
		cmd="${RIAK_BIN[$k]}riak-admin cluster join ${NODE_NAME[0]}@${NODE_ADDRESS[0]}"
		echo "JOINING ${NODE_ADDRESS[$k]}" $cmd
		ssh $USERNAME@${NODE_ADDRESS[$k]} $cmd
	fi
done

if [ ${#NODE_ADDRESS[@]} -gt 1 ]; then
cmd="${RIAK_BIN[$k]}riak-admin cluster plan && ${RIAK_BIN[$k]}riak-admin cluster commit"
echo "COMMIT ${NODE_ADDRESS[0]}"
ssh $USERNAME@${NODE_ADDRESS[0]} $cmd
fi


#for k in $(seq 0 $((${#NODE_ADDRESS[@]}-1))); do
    #SET-UP BUCKETS??
#done
