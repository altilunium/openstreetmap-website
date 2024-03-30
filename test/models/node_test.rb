require "test_helper"

class NodeTest < ActiveSupport::TestCase
  def test_node_too_far_north
    node = build(:node, :latitude => 90.01 * OldNode::SCALE)
    node.validate
    assert_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_north_limit
    node = build(:node, :latitude => 90 * OldNode::SCALE)
    node.validate
    assert_not_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_too_far_south
    node = build(:node, :latitude => -90.01 * OldNode::SCALE)
    node.validate
    assert_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_south_limit
    node = build(:node, :latitude => -90 * OldNode::SCALE)
    node.validate
    assert_not_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_too_far_west
    node = build(:node, :longitude => -180.01 * OldNode::SCALE)
    node.validate
    assert_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_west_limit
    node = build(:node, :longitude => -180 * OldNode::SCALE)
    node.validate
    assert_not_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_too_far_east
    node = build(:node, :longitude => 180.01 * OldNode::SCALE)
    node.validate
    assert_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_node_east_limit
    node = build(:node, :longitude => 180 * OldNode::SCALE)
    node.validate
    assert_not_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_totally_wrong
    node = build(:node, :latitude => 200 * OldNode::SCALE, :longitude => 200 * OldNode::SCALE)
    node.validate
    assert_includes node.errors.full_messages, "Node is not in the world"
  end

  def test_lat_lon
    node = build(:node, :latitude => 12.345 * OldNode::SCALE, :longitude => 34.567 * OldNode::SCALE)

    assert_in_delta 12.345, node.lat, 0.0000001
    assert_in_delta 34.567, node.lon, 0.0000001

    node.lat = 54.321
    node.lon = 76.543

    assert_in_delta 54.321 * OldNode::SCALE, node.latitude, 0.000001
    assert_in_delta 76.543 * OldNode::SCALE, node.longitude, 0.000001
  end

  # Check that you can create a node and store it
  def test_create
    changeset = create(:changeset)
    node_template = build(:node, :lat => 12.3456,
                                 :lon => 65.4321,
                                 :changeset_id => changeset.id,
                                 :visible => true,
                                 :version => 1)
    assert node_template.create_with_history(changeset.user)

    node = Node.find(node_template.id)
    assert_not_nil node
    assert_equal node_template.latitude, node.latitude
    assert_equal node_template.longitude, node.longitude
    assert_equal node_template.changeset_id, node.changeset_id
    assert_equal node_template.visible, node.visible
    assert_equal node_template.timestamp.to_i, node.timestamp.to_i

    assert_equal(1, OldNode.where(:node_id => node_template.id).count)
    old_node = OldNode.find_by(:node_id => node_template.id, :version => 1)
    assert_not_nil old_node
    assert_equal node_template.latitude, old_node.latitude
    assert_equal node_template.longitude, old_node.longitude
    assert_equal node_template.changeset_id, old_node.changeset_id
    assert_equal node_template.visible, old_node.visible
    assert_equal node_template.tags, old_node.tags
    assert_equal node_template.timestamp.to_i, old_node.timestamp.to_i
  end

  def test_update
    node = create(:node)
    create(:old_node, :node_id => node.id, :version => 1)
    node_template = Node.find(node.id)

    assert_not_nil node_template
    assert_equal(1, OldNode.where(:node_id => node_template.id).count)
    assert_not_nil node

    node_template.lat = 12.3456
    node_template.lon = 65.4321
    # node_template.tags = "updated=yes"
    assert node.update_from(node_template, node.changeset.user)

    node = Node.find(node_template.id)
    assert_not_nil node
    assert_equal node_template.latitude, node.latitude
    assert_equal node_template.longitude, node.longitude
    assert_equal node_template.changeset_id, node.changeset_id
    assert_equal node_template.visible, node.visible
    # assert_equal node_template.tags, node.tags

    assert_equal(2, OldNode.where(:node_id => node_template.id).count)
    old_node = OldNode.find_by(:node_id => node_template.id, :version => 2)
    assert_not_nil old_node
    assert_equal node_template.latitude, old_node.latitude
    assert_equal node_template.longitude, old_node.longitude
    assert_equal node_template.changeset_id, old_node.changeset_id
    assert_equal node_template.visible, old_node.visible
    # assert_equal node_template.tags, old_node.tags
  end

  def test_delete
    node = create(:node)
    create(:old_node, :node_id => node.id, :version => 1)
    node_template = Node.find(node.id)

    assert_not_nil node_template
    assert_equal(1, OldNode.where(:node_id => node_template.id).count)
    assert_not_nil node

    assert node.delete_with_history!(node_template, node.changeset.user)

    node = Node.find(node_template.id)
    assert_not_nil node
    assert_equal node_template.latitude, node.latitude
    assert_equal node_template.longitude, node.longitude
    assert_equal node_template.changeset_id, node.changeset_id
    assert_not node.visible
    # assert_equal node_template.tags, node.tags

    assert_equal(2, OldNode.where(:node_id => node_template.id).count)
    old_node = OldNode.find_by(:node_id => node_template.id, :version => 2)
    assert_not_nil old_node
    assert_equal node_template.latitude, old_node.latitude
    assert_equal node_template.longitude, old_node.longitude
    assert_equal node_template.changeset_id, old_node.changeset_id
    assert_not old_node.visible
    # assert_equal node_template.tags, old_node.tags
  end

  def test_from_xml_no_id
    lat = 56.7
    lon = -2.3
    changeset = 2
    version = 1
    noid = "<osm><node lat='#{lat}' lon='#{lon}' changeset='#{changeset}' version='#{version}' /></osm>"
    # First try a create which doesn't need the id
    assert_nothing_raised do
      Node.from_xml(noid, :create => true)
    end
    # Now try an update with no id, and make sure that it gives the appropriate exception
    message = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(noid, :create => false)
    end
    assert_match(/ID is required when updating./, message.message)
  end

  def test_from_xml_no_lat
    nolat = "<osm><node id='1' lon='23.3' changeset='2' version='23' /></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nolat, :create => true)
    end
    assert_match(/lat missing/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nolat, :create => false)
    end
    assert_match(/lat missing/, message_update.message)
  end

  def test_from_xml_no_lon
    nolon = "<osm><node id='1' lat='23.1' changeset='2' version='23' /></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nolon, :create => true)
    end
    assert_match(/lon missing/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nolon, :create => false)
    end
    assert_match(/lon missing/, message_update.message)
  end

  def test_from_xml_no_changeset_id
    nocs = "<osm><node id='123' lon='23.23' lat='23.1' version='23' /></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nocs, :create => true)
    end
    assert_match(/Changeset id is missing/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nocs, :create => false)
    end
    assert_match(/Changeset id is missing/, message_update.message)
  end

  def test_from_xml_no_version
    no_version = "<osm><node id='123' lat='23' lon='23' changeset='23' /></osm>"
    assert_nothing_raised do
      Node.from_xml(no_version, :create => true)
    end
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_version, :create => false)
    end
    assert_match(/Version is required when updating/, message_update.message)
  end

  def test_from_xml_double_lat
    nocs = "<osm><node id='123' lon='23.23' lat='23.1' lat='12' changeset='23' version='23' /></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nocs, :create => true)
    end
    assert_match(/Fatal error: Attribute lat redefined at/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nocs, :create => false)
    end
    assert_match(/Fatal error: Attribute lat redefined at/, message_update.message)
  end

  def test_from_xml_id_zero
    id_list = ["", "0", "00", "0.0", "a"]
    id_list.each do |id|
      zero_id = "<osm><node id='#{id}' lat='12.3' lon='12.3' changeset='33' version='23' /></osm>"
      assert_nothing_raised do
        Node.from_xml(zero_id, :create => true)
      end
      message_update = assert_raise(OSM::APIBadUserInput) do
        Node.from_xml(zero_id, :create => false)
      end
      assert_match(/ID of node cannot be zero when updating/, message_update.message)
    end
  end

  def test_from_xml_no_text
    no_text = ""
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_text, :create => true)
    end
    assert_match(/Must specify a string with one or more characters/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_text, :create => false)
    end
    assert_match(/Must specify a string with one or more characters/, message_update.message)
  end

  def test_from_xml_no_node
    no_node = "<osm></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_node, :create => true)
    end
    assert_match %r{XML doesn't contain an osm/node element}, message_create.message
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_node, :create => false)
    end
    assert_match %r{XML doesn't contain an osm/node element}, message_update.message
  end

  def test_from_xml_no_k_v
    nokv = "<osm><node id='23' lat='12.3' lon='23.4' changeset='12' version='23'><tag /></node></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nokv, :create => true)
    end
    assert_match(/tag is missing key/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(nokv, :create => false)
    end
    assert_match(/tag is missing key/, message_update.message)
  end

  def test_from_xml_no_v
    no_v = "<osm><node id='23' lat='23.43' lon='23.32' changeset='23' version='32'><tag k='key' /></node></osm>"
    message_create = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_v, :create => true)
    end
    assert_match(/tag is missing value/, message_create.message)
    message_update = assert_raise(OSM::APIBadXMLError) do
      Node.from_xml(no_v, :create => false)
    end
    assert_match(/tag is missing value/, message_update.message)
  end

  def test_from_xml_duplicate_k
    dupk = "<osm><node id='23' lat='23.2' lon='23' changeset='34' version='23'><tag k='dup' v='test' /><tag k='dup' v='tester' /></node></osm>"
    message_create = assert_raise(OSM::APIDuplicateTagsError) do
      Node.from_xml(dupk, :create => true)
    end
    assert_equal "Element node/ has duplicate tags with key dup", message_create.message
    message_update = assert_raise(OSM::APIDuplicateTagsError) do
      Node.from_xml(dupk, :create => false)
    end
    assert_equal "Element node/23 has duplicate tags with key dup", message_update.message
  end

  def test_node_tags
    node = create(:node)
    taglist = create_list(:node_tag, 2, :node => node)
    tags = Node.find(node.id).node_tags.order(:k)
    assert_equal taglist.count, tags.count
    taglist.sort_by!(&:k).each_index do |i|
      assert_equal taglist[i].k, tags[i].k
      assert_equal taglist[i].v, tags[i].v
    end
  end

  def test_tags
    node = create(:node)
    taglist = create_list(:node_tag, 2, :node => node)
    tags = Node.find(node.id).tags
    assert_equal taglist.count, tags.count
    taglist.each do |tag|
      assert_equal tag.v, tags[tag.k]
    end
  end

  def test_containing_relation_members
    node = create(:node)
    relation_member1 = create(:relation_member, :member => node)
    relation_member2 = create(:relation_member, :member => node)
    relation_member3 = create(:relation_member, :member => node)
    crm = Node.find(node.id).containing_relation_members.order(:relation_id)
    #    assert_equal 3, crm.size
    assert_equal relation_member1.relation_id, crm.first.relation_id
    assert_equal "Node", crm.first.member_type
    assert_equal node.id, crm.first.member_id
    assert_equal relation_member1.relation_id, crm.first.relation.id
    assert_equal relation_member2.relation_id, crm.second.relation_id
    assert_equal "Node", crm.second.member_type
    assert_equal node.id, crm.second.member_id
    assert_equal relation_member2.relation_id, crm.second.relation.id
    assert_equal relation_member3.relation_id, crm.third.relation_id
    assert_equal "Node", crm.third.member_type
    assert_equal node.id, crm.third.member_id
    assert_equal relation_member3.relation_id, crm.third.relation.id
  end

  def test_containing_relations
    node = create(:node)
    relation_member1 = create(:relation_member, :member => node)
    relation_member2 = create(:relation_member, :member => node)
    relation_member3 = create(:relation_member, :member => node)
    cr = Node.find(node.id).containing_relations.order(:id)

    assert_equal 3, cr.size
    assert_equal relation_member1.relation.id, cr.first.id
    assert_equal relation_member2.relation.id, cr.second.id
    assert_equal relation_member3.relation.id, cr.third.id
  end

  test "raises missing changeset exception when creating" do
    user = create(:user)
    node = Node.new
    assert_raises OSM::APIChangesetMissingError do
      node.create_with_history(user)
    end
  end

  test "raises user-changeset mismatch exception when creating" do
    user = create(:user)
    changeset = create(:changeset)
    node = Node.new(:changeset => changeset)
    assert_raises OSM::APIUserChangesetMismatchError do
      node.create_with_history(user)
    end
  end

  test "raises already closed changeset exception when creating" do
    user = create(:user)
    changeset = create(:changeset, :closed, :user => user)
    node = Node.new(:changeset => changeset)
    assert_raises OSM::APIChangesetAlreadyClosedError do
      node.create_with_history(user)
    end
  end

  test "raises id precondition exception when updating" do
    user = create(:user)
    node = Node.new(:id => 23)
    new_node = Node.new(:id => 42)
    assert_raises OSM::APIPreconditionFailedError do
      node.update_from(new_node, user)
    end
  end

  test "raises version mismatch exception when updating" do
    user = create(:user)
    node = Node.new(:id => 42, :version => 7)
    new_node = Node.new(:id => 42, :version => 12)
    assert_raises OSM::APIVersionMismatchError do
      node.update_from(new_node, user)
    end
  end

  test "raises missing changeset exception when updating" do
    user = create(:user)
    node = Node.new(:id => 42, :version => 12)
    new_node = Node.new(:id => 42, :version => 12)
    assert_raises OSM::APIChangesetMissingError do
      node.update_from(new_node, user)
    end
  end

  test "raises user-changeset mismatch exception when updating" do
    user = create(:user)
    changeset = create(:changeset)
    node = Node.new(:id => 42, :version => 12)
    new_node = Node.new(:id => 42, :version => 12, :changeset => changeset)
    assert_raises OSM::APIUserChangesetMismatchError do
      node.update_from(new_node, user)
    end
  end

  test "raises already closed changeset exception when updating" do
    user = create(:user)
    changeset = create(:changeset, :closed, :user => user)
    node = Node.new(:id => 42, :version => 12)
    new_node = Node.new(:id => 42, :version => 12, :changeset => changeset)
    assert_raises OSM::APIChangesetAlreadyClosedError do
      node.update_from(new_node, user)
    end
  end

  test "raises id precondition exception when deleting" do
    user = create(:user)
    node = Node.new(:id => 23, :visible => true)
    new_node = Node.new(:id => 42, :visible => false)
    assert_raises OSM::APIPreconditionFailedError do
      node.delete_with_history!(new_node, user)
    end
  end
end
