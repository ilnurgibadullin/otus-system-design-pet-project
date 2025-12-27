Проектирование "Системы управления системами проектирования"

В составе проекта представлены следующие артефакты:

* [Архитектурное решение](./architecture-decision.adoc)

* [Отчеты о выполнении ДЗ и проекта](./Отчет.adoc)

Используется формат описания AsciiDoc - https://docs.asciidoctor.org/asciidoc/latest/syntax-quick-reference/  

Рендер в pdf:

```
docker run --rm -v ./:/documents  asciidoctor/docker-asciidoctor asciidoctor-pdf "Архитектерное решение.adoc"
```
