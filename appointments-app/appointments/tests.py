"Unit tests for appointments"
from datetime import datetime
from zoneinfo import ZoneInfo
from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse

SERVICE_HAIRCUT = 1
HAIRDRESSER_1 = 1

#  pylint: disable=invalid-name, unused-argument
def mock_scan(TableName):
    "Mock the DynamoDB scan"
    return {
            "Items" : [
                {"Contents": {"S": "Test announcement"}}
            ]
    }

@patch('appointments.views.dynamodb.scan', mock_scan)
class AppointmentsIndexViewTests(TestCase):
    "Tests for the index view"

    def test_index(self):
        "Test the response when a service is selected"
        response = self.client.get(reverse("index"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Haircut")

    @patch("django.utils.timezone.now")
    def test_index_hairdresser(self, mock_timezone):
        """Test selecting a service & hairdresser returns dates.
        Then create a midday appointment."""
        # Mock the current time for consistent results.
        fake_date = datetime(2010, 1, 1, 10, 0, tzinfo=ZoneInfo("America/Los_Angeles"))
        mock_timezone.return_value = fake_date

        # Select a service and hairdresser.
        response = self.client.get(
            reverse("index-hairdresser", args=(SERVICE_HAIRCUT, HAIRDRESSER_1))
        )
        # Grab the first offered date.
        first_date = response.context["dates_all"][0][1]

        response = self.client.get(
            reverse("index-date", args=(SERVICE_HAIRCUT, HAIRDRESSER_1, first_date))
        )
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Time")

        #FIX(2) - initial count of available times
        available_before = response.context["start_times_available_count"]

        # Book an appt for midday.
        appt_time = "12:00"

        # Create an appointment.
        response = self.client.post(
            reverse("create"),
            {
                "service": SERVICE_HAIRCUT,
                "hairdresser": HAIRDRESSER_1,
                "date": first_date,
                "appointment_time": appt_time,
                "customer_contact": "+49123456789",
            },
        )

        #Test that the time is no longer available.
        response = self.client.get(
            reverse("index-date", args=(SERVICE_HAIRCUT, HAIRDRESSER_1, first_date))
        )
        # Build a list of the blocked times.
        blocked = [
            t["time_formatted"]
            for t in response.context["start_times_all"]
            if t["is_blocked"]
        ]
        assert appt_time in blocked, "Blocked time not found"
        # FIX(2) - Test that the number of available appointments has been reduced.
        available_after = response.context["start_times_available_count"]
        assert available_after < available_before, "Available count not decremented"

    # (3) ---1
    def test_announcements(self):
        "Test announcements are loaded"
        response = self.client.get(reverse("index"))
        assert response.context["announcements"][0] == "Test announcement"
