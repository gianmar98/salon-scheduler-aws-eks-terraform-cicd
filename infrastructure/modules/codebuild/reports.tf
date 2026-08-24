# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

locals {
  # Keys must match the `reports:` keys in buildspec_unittest.yml. CodeBuild creates a
  # group named "<project>-<key>" on the first build that publishes one.
  report_groups = {
    #Did tests pass? (reads unittests.xml when manage.py test runs)
    #  Ex:  test_index ................... PASSED  0.04s
    #       test_index_hairdresser ....... PASSED  0.11s
    UnitTests = "TEST"

    #How much of code did those tests execute? (reads coverage.xml)
    #  EX: appointments/views.py ........ 94% lines, 88% branches
    #      appointments/models.py ....... 100%
    NewCoverage = "CODE_COVERAGE"
  }
}

resource "aws_codebuild_report_group" "unittest" {
  for_each = local.report_groups

  name = "${var.unittest_codebuild_project_name}-${each.key}"
  type = each.value #Either TEST or CODE_COVERAGE

  export_config {
    type = "NO_EXPORT" #live results are only on CodeBuild, no raw files to S3
  }
}