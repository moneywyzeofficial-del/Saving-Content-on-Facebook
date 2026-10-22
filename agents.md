# Agents Guidelines – GitHub Integration

## Aplicação geral
- Sempre que um projeto possuir **link para repositório GitHub** (ex.: `origin` remoto configurado), as seguintes regras devem ser consideradas:
  1. **Sincronização automática** – o script `auto_git_push.sh` (criado na raiz do projeto) pode ser invocado manualmente ou integrado a um hook de encerramento da aplicação para fazer `git add . && git commit -m "Auto commit: <timestamp>" && git push`.
  2. **Aviso de falta de repositório** – ao iniciar ou ao efetuar alterações, se o comando `git remote get-url origin` falhar, o agente deve alertar o utilizador de que o projeto **não está ligado a um repositório no GitHub** e sugerir a criação/adição do remoto.

## Exemplo de mensagem de alerta
```
🔔 Projeto sem remote GitHub configurado.
Execute:
  git remote add origin https://github.com/your_user/your_repo.git
  git push -u origin main
para habilitar a sincronização.
```

## Como utilizar
- Coloque o arquivo `agents.md` na raiz de **todos** os projetos que utilizem GitHub.  O Antigravity lerá este ficheiro ao iniciar a sessão e aplicará as diretrizes acima.
- O script `auto_git_push.sh` já está incluído no exemplo do projeto atual; basta torná‑lo executável (`chmod +x auto_git_push.sh`).

## Notas adicionais
- Estas regras são genéricas e não interferem com projetos que **não** têm repositório remoto – nesses casos, apenas o aviso será emitido.
- Pode‑se adaptar o script para incluir mensagens de commit personalizadas ou integração com CI/CD, conforme necessário.
