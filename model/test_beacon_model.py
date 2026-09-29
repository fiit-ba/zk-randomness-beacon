import unittest

from beacon_model import BeaconModel


class BeaconModelTest(unittest.TestCase):
    def test_reveal_order_independent(self):
        a, b = BeaconModel(2), BeaconModel(2)
        for model in (a, b):
            model.register("alice", 17)
            model.register("bob", 23)
        a.reveal("alice", 17)
        a.reveal("bob", 23)
        b.reveal("bob", 23)
        b.reveal("alice", 17)
        self.assertEqual(a.finalize(b"seed"), b.finalize(b"seed"))

    def test_withholding_can_bias_or_abort(self):
        model = BeaconModel(1)
        model.register("alice", 17)
        model.register("bob", 23)
        model.reveal("alice", 17)
        without_bob = model.finalize(b"seed")
        model.reveal("bob", 23)
        self.assertNotEqual(without_bob, model.finalize(b"seed"))
        aborting = BeaconModel(2)
        aborting.register("alice", 17)
        aborting.register("bob", 23)
        aborting.reveal("alice", 17)
        self.assertIsNone(aborting.finalize(b"seed"))

    def test_invalid_disclosure(self):
        model = BeaconModel(1)
        model.register("alice", 17)
        with self.assertRaises(ValueError):
            model.reveal("alice", 18)
        model.reveal("alice", 17)
        with self.assertRaises(ValueError):
            model.reveal("alice", 17)


if __name__ == "__main__":
    unittest.main()
