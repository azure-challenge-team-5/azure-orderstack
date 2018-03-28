TEAMNAME  ?= firedragon
NAMESPACE ?= orderstack

.PHONY: all
all: azure-file-storageclass azure-capture-order azure-event-lister azure-fulfil-order

.PHONY: azure-file-storageclass
azure-file-storageclass:
	helm upgrade --install $@ $@ \
		--set location=eastus \
		--set skuName=Standard_LRS \
		--set storageAccount=orderstack 

.PHONY: azure-cosmosdb-mongo
azure-cosmosdb-mongo:
	helm upgrade --install $@ $@ \
		--namespace $(NAMESPACE) \
		--set "location=eastus"

.PHONY: amqp
amqp:
	helm upgrade --install $@ stable/rabbitmq \
		--namespace $(NAMESPACE) \
		--set rabbitmqUsername=admin \
		--set rabbitmqPassword=admin
	
.PHONY: azure-capture-order
azure-capture-order: # amqp azure-cosmosdb-mongo
	helm upgrade --install $@ $@ \
		--namespace $(NAMESPACE) \
		--set teamname=$(TEAMNAME) \
		--set "amqp.connectionString=amqp://admin:admin@amqp-rabbitmq" \
		--set "secrets.mongodb=azure-cosmosdb-mongo-azure-cosmosdb-mongo"

.PHONY: azure-event-lister
azure-event-lister: amqp azure-fulfil-order
	helm upgrade --install $@ $@ \
		--namespace $(NAMESPACE) \
		--set teamname=$(TEAMNAME) \
		--set "processor.connectionString=http://azure-fulfil-order-azure-fulfil-order/v1/order" \
		--set "amqp.connectionString=amqp://admin:admin@amqp-rabbitmq"

.PHONY: azure-fulfil-order
azure-fulfil-order: # azure-cosmosdb-mongo azure-file-storageclass
	helm upgrade --install $@ $@ \
		--namespace $(NAMESPACE) \
		--set teamname=$(TEAMNAME) \
		--set "storage.class=azure-file-storageclass-azure-file-storageclass" \
		--set "secrets.mongodb=azure-cosmosdb-mongo-azure-cosmosdb-mongo"

.PHONY: destroy
destroy:
	helm delete --purge mongodb
	helm delete --purge amqp
	helm delete --purge azure-capture-order
	helm delete --purge azure-event-lister 
	helm delete --purge azure-fulfil-order
	helm delete --purge azure-file-storageclass
