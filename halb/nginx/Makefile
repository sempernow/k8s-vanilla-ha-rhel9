APP := ngx

build:
	cat ${APP}.deploy.yaml ${APP}.cm.yaml ${APP}.svc.yaml |tee ${APP}.yaml

deploy:
	kubectl apply -f ${APP}.yaml 

deployeach:
	kubectl apply -f ${APP}.deploy.yaml -f ${APP}.cm.yaml -f ${APP}.svc.yaml 

get :
	@kubectl get node -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' \
		|xargs -I{} curl -s http://{}:30080/meta/


