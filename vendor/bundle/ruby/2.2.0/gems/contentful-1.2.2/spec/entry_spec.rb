require 'spec_helper'

describe Contentful::Entry do
  let(:entry) { vcr('entry') { create_client.entry 'nyancat' } }

  describe 'SystemProperties' do
    it 'has a #sys getter returning a hash with symbol keys' do
      expect(entry.sys).to be_a Hash
      expect(entry.sys.keys.sample).to be_a Symbol
    end

    it 'has #id' do
      expect(entry.id).to eq 'nyancat'
    end

    it 'has #type' do
      expect(entry.type).to eq 'Entry'
    end

    it 'has #space' do
      expect(entry.space).to be_a Contentful::Link
    end

    it 'has #content_type' do
      expect(entry.content_type).to be_a Contentful::Link
    end

    it 'has #created_at' do
      expect(entry.created_at).to be_a DateTime
    end

    it 'has #updated_at' do
      expect(entry.updated_at).to be_a DateTime
    end

    it 'has #revision' do
      expect(entry.revision).to eq 5
    end
  end

  describe 'Fields' do
    it 'has a #fields getter returning a hash with symbol keys' do
      expect(entry.sys).to be_a Hash
      expect(entry.sys.keys.sample).to be_a Symbol
    end

    it "contains the entry's fields" do
      expect(entry.fields[:color]).to eq 'rainbow'
      expect(entry.fields[:bestFriend]).to be_a Contentful::Link
    end
  end

  describe 'multiple locales' do
    it 'can handle multiple locales' do
      vcr('entry_locales') {
        cat = create_client.entries(locale: "*").items.first
        expect(cat.fields('en-US')[:name]).to eq "Nyan Cat"
        expect(cat.fields('es')[:name]).to eq "Gato Nyan"


        expect(cat.fields(:'en-US')[:name]).to eq "Nyan Cat"
        expect(cat.fields(:es)[:name]).to eq "Gato Nyan"
      }
    end

    describe '#fields_with_locales' do
      it 'can handle entries with just 1 locale' do
        vcr('entry') {
          nyancat = create_client.entry('nyancat')
          expect(nyancat.fields_with_locales[:name].size).to eq(1)
          expect(nyancat.fields_with_locales[:name][:'en-US']).to eq("Nyan Cat")
        }
      end

      it 'can handle entries with multiple locales' do
        vcr('entry_locales') {
          nyancat = create_client.entries(locale: "*").items.first
          expect(nyancat.fields_with_locales[:name].size).to eq(2)
          expect(nyancat.fields_with_locales[:name][:'en-US']).to eq("Nyan Cat")
          expect(nyancat.fields_with_locales[:name][:es]).to eq("Gato Nyan")
        }
      end

      it 'can have references in multiple locales and they are properly solved' do
        vcr('multi_locale_reference') {
          client = create_client(
            space: '1sjfpsn7l90g',
            access_token: 'e451a3cdfced9000220be41ed9c899866e8d52aa430eaf7c35b09df8fc6326f9',
            dynamic_entries: :auto
          )

          entry = client.entries(locale: '*').first

          expect(entry.image).to be_a ::Contentful::Asset
          expect(entry.fields('zh')[:image]).to be_a ::Contentful::Asset
          expect(entry.fields('es')[:image]).to be_a ::Contentful::Asset

          expect(entry.image.id).not_to eq entry.fields('zh')[:image].id
        }
      end

      it 'can have references with arrays in multiple locales and have them properly solved' do
        vcr('multi_locale_array_reference') {
          client = create_client(
            space: 'cma9f9g4dxvs',
            access_token: '3e4560614990c9ac47343b9eea762bdaaebd845766f619660d7230787fd545e1',
            dynamic_entries: :auto
          )

          entry = client.entries(content_type: 'test', locale: '*').first

          expect(entry.files).to be_a ::Array
          expect(entry.references).to be_a ::Array
          expect(entry.files.first).to be_a ::Contentful::Asset
          expect(entry.references.first.entry?).to be_truthy

          expect(entry.fields('zh')[:files]).to be_a ::Array
          expect(entry.fields('zh')[:references]).to be_a ::Array
          expect(entry.fields('zh')[:files].first).to be_a ::Contentful::Asset
          expect(entry.fields('zh')[:references].first.entry?).to be_truthy

          expect(entry.files.first.id).not_to eq entry.fields('zh')[:files].first.id
        }
      end
    end
  end

  it '#raw' do
    vcr('entry/raw') {
      nyancat = create_client.entry('nyancat')
      expect(nyancat.raw).to eq(create_client(raw_mode: true).entry('nyancat').object)
    }
  end

  describe 'custom resources' do
    class Kategorie < Contentful::Entry
      include ::Contentful::Resource::CustomResource

      property :title
      property :slug
      property :image
      property :top
      property :subcategories
      property :featuredArticles
      property :catIntroHead
      property :catIntroduction
      property :seoText
      property :metaKeywords
      property :metaDescription
      property :metaRobots
    end

    it 'maps fields properly' do
      vcr('entry/custom_resource') {
        entry = create_client(
          space: 'g2b4ltw00meh',
          dynamic_entries: :auto,
          entry_mapping: {
            'kategorie' => Kategorie
          }
        ).entries.first

        expect(entry).to be_a Kategorie
        expect(entry.title).to eq "Some Title"
        expect(entry.slug).to eq "/asda.html"
        expect(entry.featured_articles.first.is_a?(Contentful::Entry)).to be_truthy
        expect(entry.top).to be_truthy
      }
    end

    describe 'can be marshalled' do
      class Cat < Contentful::Entry
        include ::Contentful::Resource::CustomResource

        property :name
        property :lives
        property :bestFriend, Cat
        property :catPack
        property :image, Contentful::Asset
      end

      def test_dump(nyancat)
        dump = Marshal.dump(nyancat)
        new_cat = Marshal.load(dump)

        # Attributes
        expect(new_cat).to be_a Cat
        expect(new_cat.name).to eq "Nyan Cat"
        expect(new_cat.lives).to eq 1337

        # Single linked objects
        expect(new_cat.best_friend).to be_a Cat
        expect(new_cat.best_friend.name).to eq "Happy Cat"

        # Array of linked objects
        expect(new_cat.cat_pack.count).to eq 2
        expect(new_cat.cat_pack[0].name).to eq "Happy Cat"
        expect(new_cat.cat_pack[1].name).to eq "Worried Cat"

        # Nested Links
        expect(new_cat.best_friend.best_friend).to be_a Cat
        expect(new_cat.best_friend.best_friend.name).to eq "Worried Cat"

        # Nested array of linked objects
        expect(new_cat.best_friend.cat_pack.count).to eq 2
        expect(new_cat.best_friend.cat_pack[0].name).to eq "Nyan Cat"
        expect(new_cat.best_friend.cat_pack[1].name).to eq "Worried Cat"

        # Array of linked objects in a nested array of linked objects
        expect(new_cat.cat_pack.first.name).to eq "Happy Cat"
        expect(new_cat.cat_pack.first.cat_pack[0].name).to eq "Nyan Cat"
        expect(new_cat.cat_pack.first.cat_pack[1].name).to eq "Worried Cat"

        expect(new_cat.image.file.url).to eq "//images.contentful.com/cfexampleapi/4gp6taAwW4CmSgumq2ekUm/9da0cd1936871b8d72343e895a00d611/Nyan_cat_250px_frame.png"
      end

      it 'using entry_mapping' do
        vcr('entry/marshall') {
          nyancat = create_client(entry_mapping: {'cat' => Cat}).entries(include: 2, 'sys.id' => 'nyancat').first
          test_dump(nyancat)
        }
      end

      it 'using resource_mapping' do
        vcr('entry/marshall') {
          nyancat = create_client(resource_mapping: {
            'Entry' => ->(_json_object) do
              return Cat if _json_object.fetch('sys', {}).fetch('contentType', {}).fetch('sys', {}).fetch('id', nil) == 'cat'
              Contentful::Entry
            end
          }).entries(include: 2, 'sys.id' => 'nyancat').first
          test_dump(nyancat)
        }
      end

      it 'can remarshall an unmarshalled object' do
        vcr('entry/marshall') {
          nyancat = create_client(resource_mapping: {
            'Entry' => ->(_json_object) do
              return Cat if _json_object.fetch('sys', {}).fetch('contentType', {}).fetch('sys', {}).fetch('id', nil) == 'cat'
              Contentful::Entry
            end
          }).entries(include: 2, 'sys.id' => 'nyancat').first

          # The double load/dump is on purpose
          test_dump(Marshal.load(Marshal.dump(nyancat)))
        }
      end

      it 'newly created custom resources have property mappings' do
        entry = Cat.new

        expect(entry).to respond_to :name
        expect(entry).to respond_to :lives
        expect(entry).to respond_to :best_friend
        expect(entry).to respond_to :cat_pack
      end
    end
  end

  describe 'select operator' do
    let(:client) { create_client }

    context 'with sys sent' do
      it 'properly creates an entry' do
        vcr('entry/select_only_sys') {
          entry = client.entries(select: ['sys'], 'sys.id' => 'nyancat').first
          expect(entry.fields).to be_empty
          expect(entry.entry?).to be_truthy
        }
      end

      describe 'can contain only one field' do
        context 'with content_type sent' do
          it 'will properly create the entry with one field' do
            vcr('entry/select_one_field_proper') {
              entry = client.entries(content_type: 'cat', select: ['sys', 'fields.name'], 'sys.id' => 'nyancat').first
              expect(entry.fields).not_to be_empty
              expect(entry.entry?).to be_truthy
              expect(entry.fields[:name]).to eq 'Nyan Cat'
              expect(entry.fields).to eq({name: 'Nyan Cat'})
            }
          end
        end

        context 'without content_type sent' do
          it 'will raise an error' do
            vcr('entry/select_one_field') {
              expect { client.entries(select: ['sys', 'fields.name'], 'sys.id' => 'nyancat') }.to raise_error Contentful::BadRequest
            }
          end
        end
      end
    end

    context 'without sys sent' do
      it 'will enforce sys anyway' do
        vcr('entry/select_no_sys') {
          entry = client.entries(select: ['fields'], 'sys.id' => 'nyancat').first

          expect(entry.id).to eq 'nyancat'
          expect(entry.sys).not_to be_empty
        }
      end

      it 'works with empty array as well, as sys is enforced' do
        vcr('entry/select_empty_array') {
          entry = client.entries(select: [], 'sys.id' => 'nyancat').first

          expect(entry.id).to eq 'nyancat'
          expect(entry.sys).not_to be_empty
        }
      end
    end
  end

  describe 'issues' do
    it 'Symbol/Text field with null values should be serialized as nil - #117' do
      vcr('entries/issue_117') {
        client = create_client(space: '8jbbayggj9gj', access_token: '4ce0108f04e55c76476ba84ab0e6149734db73d67cd1b429323ef67f00977e07', dynamic_entries: :auto)
        entry = client.entries.first

        expect(entry.nil).to be_nil
        expect(entry.nil).not_to eq ''
      }
    end
  end
end
