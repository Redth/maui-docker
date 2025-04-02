# maui-docker
Docker images for MAUI dev/testing

## Building

```sh
docker build --pull --rm -f 'Dockerfile' -t 'mauidocker:latest' '.' 
```

## Running

```sh
docker run -d --device /dev/kvm -p 5554:5554 -p 5555:5555 -p 4723:4723 mauidocker:latest
```
