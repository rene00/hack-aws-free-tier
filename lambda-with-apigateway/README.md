# What?

Create an AWS [api gateway](https://aws.amazon.com/api-gateway/) resource which calls a [lambda](https://aws.amazon.com/lambda/) function.

# How?

Deploy:

```
terraform init
terraform apply
```

Grab the `base_url` terraform output which is the API gateway endpoint:

```
terraform output
```

Send a GET with no params:

```
$ http GET https://${API_GATEWAY_BASE_URL}
HTTP/1.1 200 OK
...

{
    "message": "Success."
}
```

Send a GET with `fail=true` param set:

```
$ http GET "https://${API_GATEWAY_BASE_URL}?fail=true"
HTTP/1.1 400 Bad Request
...

{
    "error": "Failing as requested."
}
```

Destroy:

```
terraform destroy
```
