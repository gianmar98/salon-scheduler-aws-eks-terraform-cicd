"App URL routes"
from django.urls import path

from . import views

urlpatterns = [
    path("", views.index, name="index"),
    path("service/<int:service_id>/", views.index, name="index-service"),
    path(
        "service/<int:service_id>/hairdresser/<int:hairdresser_id>",
        views.index,
        name="index-hairdresser",
    ),
    path(
        "service/<int:service_id>/hairdresser/<int:hairdresser_id>/date/<str:date_string>",
        views.index,
        name="index-date",
    ),
    path("create", views.create, name="create"),
]
