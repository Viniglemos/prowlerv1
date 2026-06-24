# ${{ values.appName }} - Private HTTPRoute

Este manifesto expoe a aplicacao apenas pelo Gateway privado informado.

## Validacoes antes do apply

- DNS interno aponta para o Gateway correto.
- Acesso ocorre somente via VPN/rede privada.
- O Service `${{ values.serviceName }}` existe no namespace `${{ values.namespace }}`.
- A porta `${{ values.servicePort }}` corresponde a porta do Service.

