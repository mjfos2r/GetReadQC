IMAGE_NAME = GetReadQC 
VERSION := $(shell cat .VERSION)
TAG1 = mjfos2r/$(IMAGE_NAME):$(VERSION)
TAG2 = mjfos2r/$(IMAGE_NAME):latest

all: | check tag img-build img-push 

check:
	find . -name '.venv' -prune -o -name '.git' -prune -o -regex  '.*/*.wdl' -print0 | xargs -0 miniwdl check
	find . -name '.venv' -prune -o -name '.git' -prune -o -regex  '.*\.\(ya?ml\)' -print0 | xargs -0 yamllint -d relaxed 

tag:
	git tag -s v$(VERSION) -m "Workflow version $(VERSION)"
	git push origin tag v$(VERSION)

img-build:
	docker build -t $(TAG1) -t $(TAG2) .

img-push:
	docker push $(TAG1)
	docker push $(TAG2)
