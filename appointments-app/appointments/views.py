"Appointment booking view"
import datetime
from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse
from django.contrib import messages
from django.utils import timezone

from .models import Service, Hairdresser, Appointment

def intervals_overlap(startime_1, end1, startime_2, end2):
    "Check if one interval starts after the other one ends"
    return not (end1 <= startime_2 or end2 <= startime_1)

def build_start_times(day_start, service_duration, blocked_times):
    "Build a list of start times for a given day"
    start_times = []
    for mins in range(0, 540, 30):
        time_1 = day_start + datetime.timedelta(minutes=mins)
        time_2 = time_1 + datetime.timedelta(minutes=service_duration)
        is_blocked = False

        # Don't allow appointments in the past.
        if time_1 < timezone.now():
            is_blocked = True
        else:
            # Test if the start time will overlap with any of the blocked times.
            for time in blocked_times:
                if intervals_overlap(time[0], time[1], time_1, time_2):
                    is_blocked = True

        start_times.append(
            {"time_formatted": time_1.strftime("%H:%M"), "is_blocked": is_blocked}
        )
    return start_times

def index(request, service_id=None, hairdresser_id=None, date_string=None):
    "View for selecting service, hairdresser, date and time"
    services = Service.objects.all()
    context = {"services_all": services}

    if service_id:
        context["selected_service_id"] = service_id
        context["hairdressers_all"] = Hairdresser.objects.all()

        if hairdresser_id:
            context["selected_hairdresser_id"] = hairdresser_id
            today = timezone.now().date()
            upcoming_dates = [(today + datetime.timedelta(days=d)) for d in range(7)]
            context["dates_all"] = [
                (d.strftime("%a %d %B"), d.strftime("%Y%m%d")) for d in upcoming_dates
            ]

            if date_string:
                # Find the "unavailable times".
                parsed_datetime = timezone.make_aware(
                    datetime.datetime.strptime(date_string, "%Y%m%d")
                )

                # We could write the filter to restrict to day.
                appointments = Appointment.objects.filter(
                    hairdresser__pk=hairdresser_id
                )
                blocked_times = [
                    (appt.start_datetime, appt.end_datetime)
                    for appt in appointments
                    if appt.start_datetime.date() == parsed_datetime.date()
                ]

                context["selected_date"] = date_string

                day_start = parsed_datetime.replace(
                    hour=9, minute=0, second=0, microsecond=0
                )
                service_duration = Service.objects.get(service_id=service_id).duration
                start_times = build_start_times(
                    day_start, service_duration, blocked_times
                )

                context["start_times_all"] = start_times

    return render(request, "appointments/index.html", context)

def create(request):
    "View for creating an appointment"
    if request.method == "POST":
        service_id = request.POST.get("service")
        hairdresser_id = request.POST.get("hairdresser")
        date_string = request.POST.get("date")
        appointment_time = request.POST.get("appointment_time")
        customer_contact = request.POST.get("customer_contact")

        service = Service.objects.get(service_id=service_id)
        hairdresser = Hairdresser.objects.get(hairdresser_id=hairdresser_id)
        start_datetime = timezone.make_aware(
            datetime.datetime.strptime(
                date_string + " " + appointment_time, "%Y%m%d %H:%M"
            )
        )
        end_datetime = start_datetime + datetime.timedelta(minutes=service.duration)

        Appointment.objects.create(
            service=service,
            hairdresser=hairdresser,
            start_datetime=start_datetime,
            end_datetime=end_datetime,
            customer_contact=customer_contact,
        )
        messages.info(request, "Your appointment has been created.")

    return HttpResponseRedirect(reverse("index"))
