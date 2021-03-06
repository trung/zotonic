{% extends "base.tpl" %}

{% block title %}Articles for "{{ m.rsc[q.id].title }}"{% endblock %}

{% block content %}

<h1 class="listpage">Articles for <em>{{ m.rsc[q.id].title }}</em></h1>

{% with m.search.paged[{referrers id=q.id}] as result %}
{% for id, predicate in result %}
{% include "_article_summary.tpl" id=id %}
{% endfor %}
{% pager result=result dispatch='archives_y' year=q.year %}
{% endwith %}

{% endblock %}
