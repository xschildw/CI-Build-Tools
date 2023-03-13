import datetime
from unittest import TestCase, mock, main
import dw_snapshot
import os


class MyTestCase(TestCase):

    def test_get_expiration_date_iso_default(self):
        curdate = datetime.date.today()
        expdate = dw_snapshot.get_expiration_date_iso(curdate)
        expected_expdate = (curdate + datetime.timedelta(days=21)).isoformat()
        self.assertEqual(expected_expdate, expdate)

    @mock.patch.dict(os.environ, {'DW_TTL_DAYS': '0'})
    def test_get_expiration_date_iso_none(self):
        curdate = datetime.date.today()
        expdate = dw_snapshot.get_expiration_date_iso(curdate)
        self.assertEqual('none', expdate)

    @mock.patch.dict(os.environ, {'DW_TTL_DAYS': '7'})
    def test_get_expiration_date_iso(self):
        curdate = datetime.date.today()
        expdate = dw_snapshot.get_expiration_date_iso(curdate)
        expected_expdate = (curdate + datetime.timedelta(days=7)).isoformat()
        self.assertEqual(expected_expdate, expdate)

    def test_get_expired_instances_ids_no_instances(self):
        instances = []
        expired_ids = dw_snapshot.get_expired_instances_ids(instances)
        self.assertEqual([], expired_ids)

    def test_get_expired_instances_ids_notag(self):
        instance = dict()
        instance['DBInstanceIdentifier'] = 'dbIndentifier'
        instance['TagList'] = []
        instances = [instance]
        expired_ids = dw_snapshot.get_expired_instances_ids(instances)
        self.assertEqual([], expired_ids)

    def test_get_expired_instances_ids_noexpirationtag(self):
        instance = dict()
        instance['DBInstanceIdentifier'] = 'dbIndentifier'
        instance['TagList'] = [{'Key':'OwnerEmail', 'Value': 'owner@sagebase.org'}, {'Key': 'Project', 'Value':'proj'}]
        instances = [instance]
        expired_ids = dw_snapshot.get_expired_instances_ids(instances)
        self.assertEqual([], expired_ids)

    def test_get_expired_instances_ids_expiredtag(self):
        instance = dict()
        instance['DBInstanceIdentifier'] = 'dbIdentifier'
        # expired yesterday
        exp_date_iso = (datetime.date.today() + datetime.timedelta(days=-1)).isoformat()
        instance['TagList'] = [
            {'Key': 'OwnerEmail', 'Value':'owner@sagebase.org'},
            {'Key': 'Project', 'Value':'proj'},
            {'Key': 'ExpirationDate', 'Value': exp_date_iso}]
        instances = [instance]
        expired_ids = dw_snapshot.get_expired_instances_ids(instances)
        self.assertEqual(['dbIdentifier'], expired_ids)

    def test_get_expired_instances_ids_notexpiredtag(self):
        instance = dict()
        instance['DBInstanceIdentifier'] = 'dbIdentifier'
        # expireds tomorrow
        exp_date_iso = (datetime.date.today() + datetime.timedelta(days=1)).isoformat()
        instance['TagList'] = [
            {'Key': 'OwnerEmail', 'Value':'owner@sagebase.org'},
            {'Key': 'Project', 'Value':'proj'},
            {'Key': 'ExpirationDate', 'Value': exp_date_iso}]
        instances = [instance]
        expired_ids = dw_snapshot.get_expired_instances_ids(instances)
        self.assertEqual([], expired_ids)

    def test_get_expired_instances_ids_notexpiredtagboundary(self):
        instance = dict()
        instance['DBInstanceIdentifier'] = 'dbIdentifier'
        # expires today
        exp_date_iso = datetime.date.today().isoformat()
        instance['TagList'] = [
            {'Key': 'OwnerEmail', 'Value':'owner@sagebase.org'},
            {'Key': 'Project', 'Value':'proj'},
            {'Key': 'ExpirationDate', 'Value': exp_date_iso}]
        instances = [instance]
        expired_ids = dw_snapshot.get_expired_instances_ids(instances)
        self.assertEqual([], expired_ids)

    def test_iso(self):
        date1 = datetime.date.today()
        date1_iso = date1.isoformat()
        date2 = datetime.date.fromisoformat(date1_iso)
        self.assertEqual(date1, date2)


if __name__ == '__main__':
    main()
