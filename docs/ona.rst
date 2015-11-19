Ona Support
========================


Overview
------------------------

CTS utilizes Ona to capture mobile form data. The web application communicates
with Ona via its `REST API <https://ona.io/api/v1/>`_.

Ona Secrets
------------------------

Here is the data that should be in ``conf/pillar/<environment>/secrets.sls``
to access an Ona server, for the `IQ` instance::

    secrets:
      ONA_DOMAIN_IQ: ona.io # domain of your Ona instance
      ONA_API_ACCESS_TOKEN_IQ: changeme # API access token of a valid Ona User
      ONA_PACKAGE_FORM_IDS_IQ: 23;5 # Semicolon-separated Form IDs for package/voucher tracking for this instance of the web application
      ONA_DEVICEID_VERIFICATION_FORM_ID_IQ: changeme # Form ID for binding a device to a user for this instance of the web application

Additional Forms
--------------------------

If additional form support is required, a few code changes will be necessary.
The components needed are:

  * an environment variable and/or Django setting to define the form id to capture
  * a celery task to poll and consume form submissions


Here is a made-up example::

    # Django setting
    ONA_MY_FORM_ID = os.environ.get('ONA_MY_FORM_ID', '')

    # Celery task
    @app.task
    def update_package_locations():
        """Updates the local database with new package tracking form submissions"""
        form_id = settings.ONA_MY_FORM_ID
        client = OnaApiClient()
        submissions = client.get_form_submissions(form_id)
        for data in submissions:
            submission = PackageLocationFormSubmission(data)
            if not FormSubmission.objects.filter(uuid=submission._uuid).exists():
                FormSubmission.from_ona_form_data(submission)

The above task uses a helper object, ``PackageLocationFormSubmission`` to parse the data.
For many forms, it is possible to utilize the ``OnaItemBase`` base class. Dependent on
your specific needs for the form, you may want to author a custom object based on
``OnaItemBase`` to process your form submissions.

If you need to query submissions for a specific form utilize the ``form_id`` field
to filter with::

    FormSubmission.objects.filter(form_id=settings.ONA_MY_FORM_ID)
