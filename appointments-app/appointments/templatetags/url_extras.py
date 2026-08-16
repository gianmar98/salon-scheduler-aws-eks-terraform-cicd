"helper tags for URLs"
import os
from django import template
from django.urls import reverse

register = template.Library()

def relative_url(context, view_name, *args):
    "Build a relative URL from an absolute path"
    url_string = reverse(view_name, args=args)
    start_dir = os.path.dirname(context['request'].path)
    relative_path = os.path.relpath(url_string, start=start_dir)
    return relative_path
register.simple_tag(takes_context=True)(relative_url)
