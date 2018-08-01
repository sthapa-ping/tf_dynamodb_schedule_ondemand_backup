default:
	terraform validate
	python -m py_compile source/index.py
	terraform init
	terraform apply -auto-approve
