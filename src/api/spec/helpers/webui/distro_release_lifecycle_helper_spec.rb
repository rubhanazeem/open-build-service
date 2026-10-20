RSpec.describe Webui::DistroReleaseLifecycleHelper do
  describe '#distro_release_timeline_groups' do
    let(:leap) { build_stubbed(:distro_release, name: 'Leap 15.6') }
    let(:tumbleweed) { build_stubbed(:distro_release, name: 'Tumbleweed') }

    it 'maps each distro release to an id/content pair using its name' do
      expect(distro_release_timeline_groups([leap, tumbleweed])).to eq(
        [{ id: leap.id, content: 'Leap 15.6' }, { id: tumbleweed.id, content: 'Tumbleweed' }]
      )
    end
  end

  describe '#distro_release_timeline_items' do
    subject { distro_release_timeline_items([distro_release]) }

    let(:distro_release) { create(:distro_release) }

    context 'when a distro release has no lifecycles' do
      it 'returns no items for it' do
        expect(distro_release_timeline_items([distro_release])).to eq([])
      end
    end

    context 'when a distro release has a single lifecycle' do
      let!(:lifecycle) do
        create(:distro_release_lifecycle, distro_release: distro_release,
                                          name: 'GA', status: :general_availability, date: Date.current)
      end

      it 'builds a single ongoing item open-ended a year past today' do
        expect(subject).to eq([{ id: lifecycle.id, group: distro_release.id, content: 'General Availability (ongoing)',
                                 start: lifecycle.date, end: Date.current + 1.year, title: 'GA',
                                 className: 'text-bg-success distro-release-lifecycle-ongoing' }])
      end
    end

    context 'when a distro release has multiple lifecycles out of chronological order' do
      let!(:ga) do
        create(:distro_release_lifecycle, distro_release: distro_release, name: 'GA',
                                          status: :general_availability, date: 10.days.ago.to_date)
      end

      let!(:eol) do
        create(:distro_release_lifecycle, distro_release: distro_release, name: 'EOL',
                                          status: :end_of_life, date: 10.days.from_now.to_date)
      end

      it 'sorts them by date and closes each item at the start of the next one' do
        expect(subject).to eq(
          [{ id: ga.id, group: distro_release.id, content: 'General Availability', start: ga.date, end: eol.date,
             title: 'GA', className: 'text-bg-success' }, { id: eol.id, group: distro_release.id, content: 'End of Life (ongoing)',
                                                            start: eol.date, end: eol.date + 1.year, title: 'EOL', className: 'text-bg-danger distro-release-lifecycle-ongoing' }]
        )
      end
    end

    context 'when there are multiple distro releases' do
      subject { distro_release_timeline_items([leap, tumbleweed]) }

      let(:leap) { create(:distro_release, name: 'leap') }
      let(:tumbleweed) { create(:distro_release, name: 'tumbleweed') }
      let!(:leap_lifecycle) { create(:distro_release_lifecycle, distro_release: leap, date: Date.current) }
      let!(:tumbleweed_lifecycle) { create(:distro_release_lifecycle, distro_release: tumbleweed, date: Date.current) }

      it 'groups the items under their own distro release id' do
        expect(subject.pluck(:group)).to contain_exactly(leap.id, tumbleweed.id)
        expect(subject.pluck(:id)).to contain_exactly(leap_lifecycle.id, tumbleweed_lifecycle.id)
      end
    end

    context 'when the latest lifecycle date is in the past' do
      let(:distro_release) { create(:distro_release) }
      let!(:lifecycle) { create(:distro_release_lifecycle, distro_release: distro_release, date: 10.days.ago.to_date) }

      it 'uses today plus a year as the open end date' do
        expect(subject.last[:end]).to eq(Date.current + 1.year)
        expect(lifecycle.date).to be < Date.current
      end
    end
  end
end
