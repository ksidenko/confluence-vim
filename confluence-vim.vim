
if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

function! OpenConfluencePage(article_id)
python << EOF
# the vim module contains everything we need to interface with vim
import json
import html2text
import requests
import vim

cb = vim.current.buffer

article_id = vim.eval("a:article_id")

r = requests.get('https://confluence.2gis.ru/wiki/rest/api/content/%d' % article_id, params={ 'status': 'current', 'expand': 'body.view,version.number', 'limit': 1})
vim.command("echom \"%s\"" % "\\\"".join(repr(r.text).split("\"")))
resp = json.loads(r.text)['results']
if len(resp) > 0:
    vim.command("let b:confid = %d" % int(resp[0]['id']))
    vim.command("let b:confv = %d" % int(resp[0]['version']['number']))

    article = resp[0]['body']['view']['value']
    h = html2text.HTML2Text()
    h.body_width = 0
    article_markdown = h.handle(article)
    
    del cb[:]
    for line in article_markdown.split('\n'):
        cb.append(line.encode('utf8'))
    del cb[0]
else:
    vim.command("let b:confid = 0")
    vim.command("let b:confv = 0")
    vim.command("echo \"New confluence entry - %s\"" % article_name)
vim.command("set filetype=mkd")

EOF
endfunction

function! WriteConfluencePage()
python << EOF
import json
import markdown
import requests
import vim

cb = vim.current.buffer

article_id = int(vim.eval("b:confid"))
article_v = int(vim.eval("b:confv")) + 1
article_content = markdown.markdown("\n".join(cb))

jj = {"id": str(article_id), "title": "type": "page", "version": { "number": article_v }, "body": { "storage": { "value": article_content, "representation": "storage" } } }
r = requests.put('https://confluence.2gis.ru/wiki/rest/api/content/%d' % article_id, json=jj)
vim.command("echom \"%s\"" % "\\\"".join(repr(r.text).split("\"")))

resp = json.loads(r.text)
vim.command("let b:confid = %d" % int(resp['id']))
vim.command("let b:confv = %d" % int(resp['version']['number']))
vim.command("let &modified = 0")
vim.command("echo \"Confluence entry %s written.\"" % article_name)
EOF
endfunction

augroup Confluence
  au!
  au BufReadCmd conf://* call OpenConfluencePage(expand("<amatch>"))
  au BufWriteCmd conf://* call WriteConfluencePage()
augroup END

